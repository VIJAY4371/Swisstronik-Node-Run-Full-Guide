#!/bin/bash

# ==============================================================================
# Secure Swisstronik Contract Deployment and Interaction Script
#
# This script provides a secure and organized way to deploy and interact with
# Swisstronik smart contracts. It emphasizes security by removing unsafe
# commands and using environment variables for sensitive data.
#
# Features:
# - Automated dependency checks and installation.
# - Centralized Hardhat project initialization.
# - Modular, reusable functions for contract deployment and interaction.
# - Secure handling of private keys.
# - User-friendly menu for easy navigation.
#
# Usage:
# 1. Set the required environment variables (e.g., PRIVATE_KEY).
# 2. Run the script: ./secure-script.sh
# 3. Follow the on-screen menu to choose an option.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# --- Security Validations ---

# Check for required environment variables
check_env_vars() {
  if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY environment variable is not set."
    echo "Please set it before running the script."
    exit 1
  fi
}

# --- Function Definitions ---

# Function to check for required command-line tools
check_requirements() {
  echo "Checking for required tools (node, npm, npx)..."
  for cmd in node npm npx; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: $cmd is not installed. Please install it before running."
      exit 1
    fi
  done
  echo "All required tools are installed."
}

# Function to install required npm packages
install_dependencies() {
  if [ ! -d "node_modules" ]; then
    echo "Installing required npm packages..."
    npm install dotenv @swisstronik/utils @openzeppelin/contracts @nomicfoundation/hardhat-toolbox @openzeppelin/hardhat-upgrades hardhat
  else
    echo "Dependencies already installed."
  fi
}

# Function to initialize a new Hardhat project
initialize_project() {
  echo "Initializing Hardhat project..."
  npx hardhat init --force

  # Create hardhat.config.js
  cat <<EOL > hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    swisstronik: {
      url: "https://json-rpc.testnet.swisstronik.com/",
      accounts: [\`0x\${process.env.PRIVATE_KEY}\`],
    },
  },
};
EOL
}

# Sanitize user input to prevent command injection
sanitize_input() {
  echo "$1" | sed 's/[^a-zA-Z0-9_]//g'
}

# Deploy a simple Swisstronik contract
task_1() {
  echo "Running Task 1: Deploying a simple Swisstronik contract..."

  # Create and compile the contract
  cat <<EOL > contracts/Hello_swtr.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract Swisstronik {
    string private message;

    constructor(string memory _message) {
        message = _message;
    }

    function setMessage(string memory _message) public {
        message = _message;
    }

    function getMessage() public view returns(string memory) {
        return message;
    }
}
EOL
  npx hardhat compile

  # Deploy the contract
  cat <<EOL > scripts/deploy.js
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const contract = await hre.ethers.deployContract("Swisstronik", ["Hello Swisstronik from Ga Crypto!!"]);
  await contract.waitForDeployment();
  fs.writeFileSync("contract.txt", contract.target);
  console.log(\`Swisstronik contract deployed to \${contract.target}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/deploy.js --network swisstronik

  # Create and run setMessage.js
  cat <<EOL > scripts/setMessage.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpclink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpclink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("Swisstronik");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "setMessage";
  const messageToSet = "Hello Swisstronik from GA Crypto!!";
  const setMessageTx = await sendShieldedTransaction(signer, contractAddress, contract.interface.encodeFunctionData(functionName, [messageToSet]), 0);
  await setMessageTx.wait();
  console.log("Transaction Receipt: ", setMessageTx);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/setMessage.js --network swisstronik

  # Create and run getMessage.js
  cat <<EOL > scripts/getMessage.js
const hre = require("hardhat");
const fs = require("fs");
const { decryptNodeResponse } = require("@swisstronik/utils");

const sendShieldedQuery = async (provider, destination, data) => {
  const rpclink = hre.network.config.url;
  const [encryptedData, usedEncryptedKey] = await encryptDataField(rpclink, data);
  const response = await provider.call({
    to: destination,
    data: encryptedData,
  });
  return await decryptNodeResponse(rpclink, response, usedEncryptedKey);
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("Swisstronik");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "getMessage";
  const responseMessage = await sendShieldedQuery(signer.provider, contractAddress, contract.interface.encodeFunctionData(functionName));
  console.log("Decoded response:", contract.interface.decodeFunctionResult(functionName, responseMessage)[0]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/getMessage.js --network swisstronik

  echo "Task 1 completed successfully."
}

# Create and manage a new ERC20 token
task_2() {
  echo "Running Task 2: Creating and managing a new ERC20 token..."

  # Get token details from user
  read -p "Enter the token name: " unsafe_token_name
  TOKEN_NAME=$(sanitize_input "$unsafe_token_name")
  read -p "Enter the token symbol: " unsafe_token_symbol
  TOKEN_SYMBOL=$(sanitize_input "$unsafe_token_symbol")
  read -p "Enter the recipient address for transfer: " RECIPIENT_ADDRESS

  # Create and compile the contract
  cat <<EOL > contracts/Token.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint100tokens() public {
        _mint(msg.sender, 100 * 10**18);
    }

    function burn100tokens() public {
        _burn(msg.sender, 100 * 10**18);
    }
}
EOL
  npx hardhat compile

  # Deploy the contract
  cat <<EOL > scripts/deploy.js
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const contract = await hre.ethers.deployContract("TestToken", ["$TOKEN_NAME", "$TOKEN_SYMBOL"]);
  await contract.waitForDeployment();
  fs.writeFileSync("contract.txt", contract.target);
  console.log(\`Contract deployed to \${contract.target}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/deploy.js --network swisstronik

  # Create and run mint.js
  cat <<EOL > scripts/mint.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("TestToken");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "mint100tokens";
  const mint100TokensTx = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName),
    0
  );
  await mint100TokensTx.wait();
  console.log("Transaction Receipt: ", \`Minting token has been successful! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${mint100TokensTx.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/mint.js --network swisstronik

  # Create and run transfer.js
  cat <<EOL > scripts/transfer.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("TestToken");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "transfer";
  const amount = ethers.parseUnits("1", "ether");
  const functionArgs = ["$RECIPIENT_ADDRESS", amount.toString()];
  const transaction = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName, functionArgs),
    0
  );
  await transaction.wait();
  console.log("Transaction Response: ", \`Transfer token has been successful! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${transaction.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/transfer.js --network swisstronik

  echo "Task 2 completed successfully."
}

# Create and manage a new NFT
task_3() {
  echo "Running Task 3: Creating and managing a new NFT..."

  # Get NFT details from user
  read -p "Enter the NFT name: " unsafe_nft_name
  NFT_NAME=$(sanitize_input "$unsafe_nft_name")
  read -p "Enter the NFT symbol: " unsafe_nft_symbol
  NFT_SYMBOL=$(sanitize_input "$unsafe_nft_symbol")

  # Create and compile the contract
  cat <<EOL > contracts/NFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract TestNFT is ERC721, ERC721Burnable {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function safeMint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }
}
EOL
  npx hardhat compile

  # Deploy the contract
  cat <<EOL > scripts/deploy.js
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const contract = await hre.ethers.deployContract("TestNFT", ["$NFT_NAME", "$NFT_SYMBOL"]);
  await contract.waitForDeployment();
  fs.writeFileSync("contract.txt", contract.target);
  console.log(\`Contract deployed to \${contract.target}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/deploy.js --network swisstronik

  # Create and run mint.js
  cat <<EOL > scripts/mint.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("TestNFT");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "safeMint";
  const safeMintTx = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName, [signer.address, 1]),
    0
  );
  await safeMintTx.wait();
  console.log("Transaction Receipt: ", \`Minting NFT has been successful! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${safeMintTx.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/mint.js --network swisstronik

  echo "Task 3 completed successfully."
}

# Deploy and interact with a PERC20 token
task_4() {
  echo "Running Task 4: Deploying and interacting with a PERC20 token..."

  # Get token details from user
  read -p "Enter the token name: " unsafe_token_name
  TOKEN_NAME=$(sanitize_input "$unsafe_token_name")
  read -p "Enter the token symbol: " unsafe_token_symbol
  TOKEN_SYMBOL=$(sanitize_input "$unsafe_token_symbol")
  read -p "Enter the recipient address for transfer: " RECIPIENT_ADDRESS

  # Create and compile the contracts
  cat <<EOL > contracts/IPERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
EOL

  cat <<EOL > contracts/IPERC20Metadata.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IPERC20.sol";

interface IERC20Metadata is IPERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
EOL

  cat <<EOL > contracts/PERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IPERC20.sol";
import "./IPERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract PERC20 is Context, IPERC20, IERC20Metadata {
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) { return _name; }
    function symbol() public view virtual override returns (string memory) { return _symbol; }
    function decimals() public view virtual override returns (uint8) { return 18; }
    function totalSupply() public view virtual override returns (uint256) { return _totalSupply; }
    function balanceOf(address) public view virtual override returns (uint256) { revert("PERC20: default \`balanceOf\` function is disabled"); }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address, address) public view virtual override returns (uint256) { revert("PERC20: default \`allowance\` function is disabled"); }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "PERC20: transfer amount exceeds allowance");
        unchecked { _approve(sender, _msgSender(), currentAllowance - amount); }
        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "PERC20: transfer from the zero address");
        require(recipient != address(0), "PERC20: transfer to the zero address");
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "PERC20: transfer amount exceeds balance");
        unchecked { _balances[sender] = senderBalance - amount; }
        _balances[recipient] += amount;
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "PERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
    }
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "PERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "PERC20: burn amount exceeds balance");
        unchecked { _balances[account] = accountBalance - amount; }
        _totalSupply -= amount;
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "PERC20: approve from the zero address");
        require(spender != address(0), "PERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
    }
}
EOL

  cat <<EOL > contracts/PERC20Sample.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./PERC20.sol";

contract PERC20Sample is PERC20 {
    constructor(string memory name, string memory symbol) PERC20(name, symbol) {}

    function mint100tokens() public {
        _mint(msg.sender, 100 * 10**18);
    }

    function balanceOf(address account) public view override returns (uint256) {
        require(msg.sender == account, "PERC20Sample: msg.sender != account");
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        require(msg.sender == spender, "PERC20Sample: msg.sender != account");
        return _allowances[owner][spender];
    }
}
EOL
  npx hardhat compile

  # Deploy the contract
  cat <<EOL > scripts/deploy.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  const perc20 = await ethers.deployContract("PERC20Sample", ["$TOKEN_NAME", "$TOKEN_SYMBOL"]);
  await perc20.waitForDeployment();
  fs.writeFileSync("contract.txt", perc20.target);
  console.log(\`PERC20Sample was deployed to: \${perc20.target}\`)
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/deploy.js --network swisstronik

  # Create and run mint.js
  cat <<EOL > scripts/mint.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("PERC20Sample");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "mint100tokens";
  const mint100TokensTx = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName),
    0
  );
  await mint100TokensTx.wait();
  console.log("Transaction Receipt: ", \`Minting token has been successful! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${mint100TokensTx.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/mint.js --network swisstronik

  # Create and run transfer.js
  cat <<EOL > scripts/transfer.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("PERC20Sample");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "transfer";
  const amount = ethers.parseUnits("1", "ether");
  const functionArgs = ["$RECIPIENT_ADDRESS", amount.toString()];
  const transaction = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName, functionArgs),
    0
  );
  await transaction.wait();
  console.log("Transaction Response: ", \`Transfer token has been successful! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${transaction.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/transfer.js --network swisstronik

  echo "Task 4 completed successfully."
}

# Create and manage a private NFT
task_5() {
  echo "Running Task 5: Creating and managing a private NFT..."

  # Get NFT details from user
  read -p "Enter the NFT name: " unsafe_nft_name
  NFT_NAME=$(sanitize_input "$unsafe_nft_name")
  read -p "Enter the NFT symbol: " unsafe_nft_symbol
  NFT_SYMBOL=$(sanitize_input "$unsafe_nft_symbol")

  # Create and compile the contract
  cat <<EOL > contracts/PrivateNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrivateNFT is ERC721, ERC721Burnable, Ownable {
    constructor(string memory name, string memory symbol, address initialOwner)
        ERC721(name, symbol)
        Ownable(initialOwner)
    {}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function balanceOf(address owner) public view override returns (uint256) {
        require(msg.sender == owner, "PrivateNFT: msg.sender != owner");
        return super.balanceOf(owner);
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = super.ownerOf(tokenId);
        require(msg.sender == owner, "PrivateNFT: msg.sender != owner");
        return owner;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address owner = super.ownerOf(tokenId);
        require(msg.sender == owner, "PrivateNFT: msg.sender != owner");
        return super.tokenURI(tokenId);
    }
}
EOL
  npx hardhat compile

  # Deploy the contract
  cat <<EOL > scripts/deploy.js
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("PrivateNFT");
  const contract = await contractFactory.deploy("$NFT_NAME", "$NFT_SYMBOL", deployer.address);
  await contract.waitForDeployment();
  fs.writeFileSync("contract.txt", contract.target);
  console.log(\`Contract deployed to \${contract.target}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/deploy.js --network swisstronik

  # Create and run mint.js
  cat <<EOL > scripts/mint.js
const hre = require("hardhat");
const fs = require("fs");
const { encryptDataField } = require("@swisstronik/utils");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpcLink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpcLink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("PrivateNFT");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "safeMint";
  const safeMintTx = await sendShieldedTransaction(
    signer,
    contractAddress,
    contract.interface.encodeFunctionData(functionName, [signer.address, 1]),
    0
  );
  await safeMintTx.wait();
  console.log("Transaction Receipt: ", \`Minting NFT has been successful! Transaction hash: https://explorer-evm.testnet.swisstronik.com/tx/\${safeMintTx.hash}\`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/mint.js --network swisstronik

  echo "Task 5 completed successfully."
}

# Deploy an upgradable Swisstronik contract
task_6() {
  echo "Running Task 6: Deploying an upgradable Swisstronik contract..."

  # Create and compile the contract
  cat <<EOL > contracts/Hello_swtr.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Swisstronik is Initializable {
    string private message;

    function initialize(string memory _message) public initializer {
        message = _message;
    }

    function setMessage(string memory _message) public {
        message = _message;
    }

    function getMessage() public view returns(string memory) {
        return message;
    }
}
EOL
  npx hardhat compile

  # Deploy the contract
  cat <<EOL > scripts/deploy.js
const { ethers, upgrades } = require("hardhat");
const fs = require("fs");

async function main() {
  const Swisstronik = await ethers.getContractFactory('Swisstronik');
  const swisstronik = await upgrades.deployProxy(Swisstronik, ['Hello Swisstronik from Happy Cuan Airdrop!!'], { kind: 'transparent' });
  await swisstronik.waitForDeployment();
  fs.writeFileSync("contract.txt", swisstronik.target);
  console.log('Proxy Swisstronik deployed to:', swisstronik.target);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOL
  npx hardhat run scripts/deploy.js --network swisstronik

  # Create and run setMessage.js
  cat <<EOL > scripts/setMessage.js
const hre = require("hardhat");
const { encryptDataField } = require("@swisstronik/utils");
const fs = require("fs");

const sendShieldedTransaction = async (signer, destination, data, value) => {
  const rpclink = hre.network.config.url;
  const [encryptedData] = await encryptDataField(rpclink, data);
  return await signer.sendTransaction({
    from: signer.address,
    to: destination,
    data: encryptedData,
    value,
  });
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("Swisstronik");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "setMessage";
  const messageToSet = "Hello Swisstronik from Happy Cuan Airdrop!!";
  const setMessageTx = await sendShieldedTransaction(signer, contractAddress, contract.interface.encodeFunctionData(functionName, [messageToSet]), 0);
  await setMessageTx.wait();
  console.log("Transaction Receipt: ", setMessageTx);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/setMessage.js --network swisstronik

  # Create and run getMessage.js
  cat <<EOL > scripts/getMessage.js
const hre = require("hardhat");
const { decryptNodeResponse } = require("@swisstronik/utils");
const fs = require("fs");

const sendShieldedQuery = async (provider, destination, data) => {
  const rpclink = hre.network.config.url;
  const [encryptedData, usedEncryptedKey] = await encryptDataField(rpclink, data);
  const response = await provider.call({
    to: destination,
    data: encryptedData,
  });
  return await decryptNodeResponse(rpclink, response, usedEncryptedKey);
};

async function main() {
  const contractAddress = fs.readFileSync("contract.txt", "utf8").trim();
  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory("Swisstronik");
  const contract = contractFactory.attach(contractAddress);
  const functionName = "getMessage";
  const responseMessage = await sendShieldedQuery(signer.provider, contractAddress, contract.interface.encodeFunctionData(functionName));
  console.log("Decoded response:", contract.interface.decodeFunctionResult(functionName, responseMessage)[0]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
EOL
  npx hardhat run scripts/getMessage.js --network swisstronik

  echo "Task 6 completed successfully."
}

# Function to clean up generated files
cleanup() {
  echo "Cleaning up generated files..."
  rm -rf contracts/ scripts/ cache/ artifacts/ node_modules/ package.json package-lock.json hardhat.config.js contract.txt
  echo "Cleanup complete."
}

# --- Main Menu ---

main_menu() {
  while true; do
    echo "========================================"
    echo "  Secure Swisstronik Script Menu"
    echo "========================================"
    echo "1. Deploy a simple Swisstronik contract"
    echo "2. Create and manage a new ERC20 token"
    echo "3. Create and manage a new NFT"
    echo "4. Deploy and interact with a PERC20 token"
    echo "5. Create and manage a new private NFT"
    echo "6. Deploy an upgradable Swisstronik contract"
    echo "7. Cleanup generated files"
    echo "8. Exit"
    echo "========================================"
    read -p "Choose an option: " choice

    case $choice in
      1) task_1 ;;
      2) task_2 ;;
      3) task_3 ;;
      4) task_4 ;;
      5) task_5 ;;
      6) task_6 ;;
      7) cleanup ;;
      8) exit 0 ;;
      *) echo "Invalid option. Please try again." ;;
    esac
  done
}

# --- Script Execution ---

check_env_vars
check_requirements
install_dependencies
initialize_project
main_menu
