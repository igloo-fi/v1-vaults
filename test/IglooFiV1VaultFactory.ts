import { expect } from "chai";
const { ethers } = require("hardhat");

describe("IglooFi V1 Vault Factory", async () => {
	let testIglooFiGovernance: any;
	let iglooFiV1VaultFactory: any;
	
	/**
	 * @dev Deploy TestIglooFiGovernance.sol
	*/
	before("[before] Deploy IglooFiGovernance contract..", async () => {
		const TestIglooFiGovernance = await ethers.getContractFactory(
			"TestIglooFiGovernance"
		);

		testIglooFiGovernance = await TestIglooFiGovernance.deploy();
		testIglooFiGovernance = await testIglooFiGovernance.deployed();
	});

	/**
	 * @dev Deploy IglooFiV1VaultFactory.sol
	*/
	before("[before] Deploy IglooFiV1VaultFactory contracts..", async () => {
		const IglooFiV1VaultFactory = await ethers.getContractFactory(
			"IglooFiV1VaultFactory"
		);

		iglooFiV1VaultFactory = await IglooFiV1VaultFactory.deploy(
			testIglooFiGovernance.address
		);
		iglooFiV1VaultFactory = await iglooFiV1VaultFactory.deployed();
	});

	/**
	* @dev recieve
	*/
	describe("Contract", async () => {
		it(
			"Should be able to recieve ether..",
			async () => {
				const [, addr1] = await ethers.getSigners();
				
				// Send ether to IglooFiV1VaultFactory contract
				await addr1.sendTransaction({
					to: iglooFiV1VaultFactory.address,
					value: ethers.utils.parseEther("1"),
				});
	
				await expect(
					await ethers.provider.getBalance(iglooFiV1VaultFactory.address)
				).to.be.greaterThanOrEqual(ethers.utils.parseEther("1"));
			}
		);
	})


	/**
	* @dev Initial values set by constructor
	*/
	describe("Constructor Initialized values", async () => {
		/**
		 * @notice Check if initial values are correct
		*/
		it(
			"Should intialize pause as true..",
			async () => {
				expect(await iglooFiV1VaultFactory.paused()).to.equal(true);
			}
		);
	
		it(
			"Should initialize `IGLOO_FI` to `TestIglooFiGovernance` address..",
			async () => {
				expect(await iglooFiV1VaultFactory.IGLOO_FI()).to.equal(
					testIglooFiGovernance.address
				);
			}
		);
	
		it(
			"Should initialize the `fee` to 0..",
			async () => {
				expect(await iglooFiV1VaultFactory.fee()).to.equal(0);
			}
		);
	});


	/**
	 * @dev admin
	*/
	describe("Auth: DEFAULT_ADMIN_ROLE", async () => {
		/**
		* @dev setPause
		*/
		describe("setPause", async () => {
			it(
				"Should revert when unauthorized msg.sender calls..",
				async () => {
					const [, addr1] = await ethers.getSigners();
		
					await expect(iglooFiV1VaultFactory.connect(addr1).setPause(false))
						.to.be.rejectedWith("!auth")
					;
				}
			);
			
			it(
				"Should be able to set true..",
				async () => {
					await iglooFiV1VaultFactory.setPause(false);
					
					expect(await iglooFiV1VaultFactory.paused()).to.be.false;
				}
			);

			it(
				"Should be able to set false..",
				async () => {
					await iglooFiV1VaultFactory.setPause(true);
					
					expect(await iglooFiV1VaultFactory.paused()).to.be.true;
				
					// Unpause for the rest of the test
					await iglooFiV1VaultFactory.setPause(false);
				}
			);
		});


		/**
		* @dev updateFee
		*/
		describe("updateFee", async () => {
			it(
				"Should revert when unauthorized msg.sender calls..",
				async () => {
					const [, addr1] = await ethers.getSigners();

					await expect(iglooFiV1VaultFactory.connect(addr1).updateFee(2))
						.to.be.rejectedWith("!auth")
					;
				}
			);

			it(
				"Should update correctly..",
				async () => {
					await iglooFiV1VaultFactory.updateFee(1);

					expect(await iglooFiV1VaultFactory.fee()).to.equal(1);
				}
			);
		});


		/**
		* @dev transferFunds
		*/
		describe("transferFunds", async () => {
			it(
				"Should revert when unauthorized msg.sender calls..",
				async () => {
					const [, addr1] = await ethers.getSigners();
		
					await expect(
						iglooFiV1VaultFactory.connect(addr1).transferFunds(addr1.address)
					).to.be.rejectedWith("!auth");
				}
			);

			it(
				"Should be able to transfer to an address..",
				async () => {
					const [, addr1] = await ethers.getSigners();
		
					const balanceBefore = {
						addr1: parseFloat(
							ethers.utils.formatUnits(
								(await ethers.provider.getBalance(addr1.address)),
								"ether"
							)
						),
						iglooFiV1VaultFactory: parseFloat(
							ethers.utils.formatUnits(
								(await ethers.provider.getBalance(iglooFiV1VaultFactory.address)),
								"ether"
							)
						)
					};
		
					await iglooFiV1VaultFactory.transferFunds(addr1.address);
		
					const balanceAfter = {
						addr1: parseFloat(
							ethers.utils.formatUnits(
								(await ethers.provider.getBalance(addr1.address)),
								"ether"
							)
						),
						iglooFiV1VaultFactory: parseFloat(
							ethers.utils.formatUnits(
								(await ethers.provider.getBalance(iglooFiV1VaultFactory.address)),
								"ether"
							)
						)
					};
		
					await expect(balanceAfter.addr1).to.be.equal(
						balanceBefore.addr1 + balanceBefore.iglooFiV1VaultFactory
					);
				}
			);
		});
	});


	/**
	* @dev deployVault
	*/
	describe("deployVault", async () => {
		it(
			"Should be able to record deployed IglooFiV1Vault.sol..",
			async () => {
				const [, addr1] = await ethers.getSigners();

				const deployedAddress = await iglooFiV1VaultFactory.deployVault(
					addr1.address,
					2,
					10,
					{ value: 1 }
				)

				expect(await iglooFiV1VaultFactory.vaultAddress(0))
					.to.equal((await deployedAddress.wait()).events[1].args[0])
				;
			}
		);


		/**
		* @dev IglooFiV1VaultFactory.sol Deployed: IglooFiV1.sol
		*/
		describe("IglooFiV1VaultFactory.sol Deployed: IglooFiV1.sol", async () => {
			it(
				"Should have admin set properly..",
				async () => {
					const [, addr1] = await ethers.getSigners();
					
					let deployedAddress = await iglooFiV1VaultFactory.vaultAddress(0);

					const IglooFiV1Vault = await ethers.getContractFactory("IglooFiV1Vault");

					const iglooFiV1Vault = await IglooFiV1Vault.attach(deployedAddress);

					expect(
						await iglooFiV1Vault.hasRole(
							await iglooFiV1Vault.DEFAULT_ADMIN_ROLE(),
							addr1.address
						)
					).to.equal(true);
				}
			);
		});
	});
})
