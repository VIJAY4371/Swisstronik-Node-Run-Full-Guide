# Secure Swisstronik Contract Deployment and Interaction Script

This repository contains a secure script for deploying and interacting with Swisstronik smart contracts. The `secure-script.sh` consolidates the functionality of the previous insecure scripts into a single, robust, and user-friendly solution.

## Security First

The primary goal of this script is to provide a secure environment for managing your Swisstronik contracts. It enforces security best practices by:

- **Eliminating Remote Code Execution**: The script does not download or execute remote scripts.
- **Secure Private Key Handling**: It requires the private key to be set as an environment variable, preventing it from being stored in plaintext or passed as a command-line argument.
- **No Unnecessary Privileges**: The script does not use `sudo`, reducing its attack surface.

## Prerequisites

Before using the script, you need to have the following installed:

- **Node.js and npm**: [https://nodejs.org/](https://nodejs.org/)
- **Hardhat**: You can install it locally by running `npm install --save-dev hardhat` in your project directory.

## Setup

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

2.  **Install dependencies**:
    ```bash
    npm install dotenv @swisstronik/utils @openzeppelin/contracts @nomicfoundation/hardhat-toolbox @openzeppelin/hardhat-upgrades hardhat
    ```

3.  **Set the `PRIVATE_KEY` environment variable**:
    The script requires your private key to be set as an environment variable. You can do this in your shell's configuration file (e.g., `.bashrc`, `.zshrc`) or by exporting it in your current session:
    ```bash
    export PRIVATE_KEY="your-private-key-without-0x"
    ```
    **IMPORTANT**: Do not include the `0x` prefix in your private key.

## Usage

1.  **Make the script executable**:
    ```bash
    chmod +x secure-script.sh
    ```

2.  **Run the script**:
    ```bash
    ./secure-script.sh
    ```

3.  **Choose an option from the menu**:
    The script will present you with a menu of options. Simply enter the number corresponding to the task you want to perform.

    ```
    ========================================
      Secure Swisstronik Script Menu
    ========================================
    1. Deploy a simple Swisstronik contract
    2. Create and manage a new ERC20 token
    3. Create and manage a new NFT
    4. Deploy and interact with a PERC20 token
    5. Create and manage a private NFT
    6. Deploy an upgradable Swisstronik contract
    7. Exit
    ========================================
    ```

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.
