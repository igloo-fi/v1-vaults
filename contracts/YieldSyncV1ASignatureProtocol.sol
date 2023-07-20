// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


import { IAccessControlEnumerable } from "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IYieldSyncV1Vault } from "@yield-sync/v1-sdk/contracts/interface/IYieldSyncV1Vault.sol";

import { ISignatureProtocol, MessageHashData } from "./interface/ISignatureProtocol.sol";
import { IYieldSyncV1ASignatureProtocol, MessageHashVote } from "./interface/IYieldSyncV1ASignatureProtocol.sol";
import { IYieldSyncV1VaultAccessControl } from "./interface/IYieldSyncV1VaultAccessControl.sol";


contract YieldSyncV1ASignatureProtocol is
	Pausable,
	ISignatureProtocol,
	IYieldSyncV1ASignatureProtocol
{
	address public immutable override YieldSyncGovernance;
	address public immutable override YieldSyncV1VaultAccessControl;

	bytes4 public constant ERC1271_MAGIC_VALUE = 0x1626ba7e;

	mapping (address yieldSyncV1VaultAddress => bytes32[] messageHash) internal _vaultMessageHashes;

	mapping (
		address yieldSyncV1VaultAddress => uint256 signaturesRequired
	) internal _yieldSyncV1VaultAddress_signaturesRequired;

	mapping (
		address yieldSyncV1VaultAddress => mapping (bytes32 messageHash => MessageHashData messageHashData)
	) internal _yieldSyncV1VaultAddress_messageHash_messageHashData;

	mapping (
		address yieldSyncV1VaultAddress => mapping (bytes32 messageHash => MessageHashVote messageHashVote)
	) internal _yieldSyncV1VaultAddress_messageHash_messageHashVote;


	modifier contractYieldSyncGovernance(bytes32 role)
	{
		require(IAccessControlEnumerable(YieldSyncGovernance).hasRole(role, msg.sender), "!auth");

		_;
	}

	modifier contractYieldSyncV1Vault(address yieldSyncV1VaultAddress)
	{
		require(msg.sender == yieldSyncV1VaultAddress, "!yieldSyncV1VaultAddress");

		_;
	}


	constructor (address _YieldSyncGovernance, address _YieldSyncV1VaultAccessControl)
	{
		_pause();

		YieldSyncGovernance = _YieldSyncGovernance;
		YieldSyncV1VaultAccessControl = _YieldSyncV1VaultAccessControl;
	}


	/// @inheritdoc ISignatureProtocol
	function isValidSignature(bytes32 _messageHash, bytes memory _signature)
		public
		view
		override
		returns (bytes4 magicValue)
	{
		address recovered = ECDSA.recover(ECDSA.toEthSignedMessageHash(_messageHash), _signature);

		MessageHashData memory messageHashData = _yieldSyncV1VaultAddress_messageHash_messageHashData[msg.sender][
			_messageHash
		];

		MessageHashVote memory messageHashVote = _yieldSyncV1VaultAddress_messageHash_messageHashVote[msg.sender][
			_messageHash
		];

		return (
			_vaultMessageHashes[msg.sender][_vaultMessageHashes[msg.sender].length -1] == _messageHash &&
			messageHashData.signer == recovered &&
			messageHashVote.signatureCount >= _yieldSyncV1VaultAddress_signaturesRequired[msg.sender]
		) ? ERC1271_MAGIC_VALUE : bytes4(0);
	}


	/// @inheritdoc ISignatureProtocol
	function yieldSyncV1VaultInitialize(address initiator, address yieldSyncV1VaultAddress)
		public
		override
		contractYieldSyncV1Vault(yieldSyncV1VaultAddress)
	{
		require(
			_yieldSyncV1VaultAddress_signaturesRequired[initiator] > 0,
			"!_yieldSyncV1VaultAddress_signaturesRequired[initiator]"
		);

		_yieldSyncV1VaultAddress_signaturesRequired[
			yieldSyncV1VaultAddress
		] = _yieldSyncV1VaultAddress_signaturesRequired[
			initiator
		];
	}


	/// @inheritdoc IYieldSyncV1ASignatureProtocol
	function vaultMessageHashes(address yieldSyncV1VaultAddress)
		public
		view
		override
		returns (bytes32[] memory)
	{
		return _vaultMessageHashes[yieldSyncV1VaultAddress];
	}

	/// @inheritdoc IYieldSyncV1ASignatureProtocol
	function yieldSyncV1VaultAddress_signaturesRequired(address purposer)
		public
		view
		override
		returns (uint256)
	{
		return _yieldSyncV1VaultAddress_signaturesRequired[purposer];
	}

	/// @inheritdoc IYieldSyncV1ASignatureProtocol
	function yieldSyncV1VaultAddress_messageHash_messageHashData(address yieldSyncV1VaultAddress, bytes32 messageHash)
		public
		view
		override
		returns (MessageHashData memory)
	{
		return _yieldSyncV1VaultAddress_messageHash_messageHashData[yieldSyncV1VaultAddress][messageHash];
	}

	/// @inheritdoc IYieldSyncV1ASignatureProtocol
	function yieldSyncV1VaultAddress_messageHash_messageHashVote(address yieldSyncV1VaultAddress, bytes32 messageHash)
		public
		view
		override
		returns (MessageHashVote memory)
	{
		return _yieldSyncV1VaultAddress_messageHash_messageHashVote[yieldSyncV1VaultAddress][messageHash];
	}


	/// @inheritdoc IYieldSyncV1ASignatureProtocol
	function yieldSyncV1VaultAddress_signaturesRequiredUpdate(uint256 signatureRequired)
		public
		override
	{
		_yieldSyncV1VaultAddress_signaturesRequired[msg.sender] = signatureRequired;
	}

	/// @inheritdoc IYieldSyncV1ASignatureProtocol
	function signMessageHash(address yieldSyncV1VaultAddress, bytes32 messageHash, bytes memory signature)
		public
		override
		whenNotPaused()
	{
		(, bool member) = IYieldSyncV1VaultAccessControl(
			YieldSyncV1VaultAccessControl
		).yieldSyncV1VaultAddress_participant_access(
			yieldSyncV1VaultAddress,
			msg.sender
		);

		require(member, "!member");

		MessageHashData memory messageHashData = _yieldSyncV1VaultAddress_messageHash_messageHashData[
			yieldSyncV1VaultAddress
		][
			messageHash
		];

		MessageHashVote memory messageHashVote = _yieldSyncV1VaultAddress_messageHash_messageHashVote[
			yieldSyncV1VaultAddress
		][
			messageHash
		];

		for (uint i = 0; i < messageHashVote.signedMembers.length; i++)
		{
			require(messageHashVote.signedMembers[i] != msg.sender, "Already signed");
		}

		if (messageHashData.signer == address(0))
		{
			address[] memory initialsignedMembers;

			address recovered = ECDSA.recover(ECDSA.toEthSignedMessageHash(messageHash), signature);

			(
				,
				bool recoveredIsMember
			) = IYieldSyncV1VaultAccessControl(YieldSyncV1VaultAccessControl).yieldSyncV1VaultAddress_participant_access(
				yieldSyncV1VaultAddress,
				recovered
			);

			require(recoveredIsMember, "!member");

			_yieldSyncV1VaultAddress_messageHash_messageHashData[yieldSyncV1VaultAddress][
				messageHash
			] = MessageHashData({
				signature: signature,
				signer: recovered
			});

			_yieldSyncV1VaultAddress_messageHash_messageHashVote[yieldSyncV1VaultAddress][
				messageHash
			] = MessageHashVote({
				signedMembers: initialsignedMembers,
				signatureCount: 0
			});

			_vaultMessageHashes[yieldSyncV1VaultAddress].push(messageHash);
		}

		_yieldSyncV1VaultAddress_messageHash_messageHashVote[yieldSyncV1VaultAddress][messageHash].signedMembers.push(
			msg.sender
		);

		_yieldSyncV1VaultAddress_messageHash_messageHashVote[yieldSyncV1VaultAddress][messageHash].signatureCount++;
	}


	/// @inheritdoc IYieldSyncV1ASignatureProtocol
	function updatePause(bool pause)
		public
		override
		contractYieldSyncGovernance(bytes32(0))
	{
		if (pause)
		{
			_pause();
		}
		else
		{
			_unpause();
		}
	}
}
