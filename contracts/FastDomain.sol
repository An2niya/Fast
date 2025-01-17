//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC20 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);

    function transfer(address _to, uint256 _amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

interface IFastDomainNFT {
    function awardUser(address user) external returns (uint256);
}

contract FastDomain {
    /////////////////EVENTS////////////////
    //DomainEvent is emitted when a domain is registered.
    //This event allows external parties to listen and react to domain registration events.
    event DomainEvent(string domain, address user);

    ////////////////STATE//////////////////
    IERC20 tokenAddr; //address of the ERC20 token contract used for transactions within the FastDomain DApp.
    IFastDomainNFT nftAddr;
    mapping(address => string) userNames; //associates user addresses with their registered domain names.
    mapping(string => bool) registeredDomainUsers; //keeps track of registered domain names and their ownership status.
    mapping(address => bool) registered; //keeps track of whether an address has already registered a domain or not.
    mapping(address => uint256) userDomains; // new mapping to track the index of each user's domain name
    mapping(address => bool) hasMinted; //keeps track of whether an address has already minted tokens or not.
    mapping(address => uint256) userNFTId;

    string[] AllRegisteredDomains;

    uint256 amountToMint = 2 * 10 ** 18;

    ///////////////ERROR///////////////
    error ZeroAddress();
    error DomainExists();
    error GetToken();
    error HasAlreadyMinted();
    error InsufficientToken();
    error NotOwner();
    error AddressDontHaveFastDomain();

    constructor(IERC20 _fastTokenAddress, IFastDomainNFT _nftAddr) {
        tokenAddr = _fastTokenAddress;
        nftAddr = _nftAddr;
    }

    /// @dev mintToken function allows users to mint tokens for testing purposes
    function mintToken() external returns (string memory) {
        if (hasMinted[msg.sender] == true) {
            revert HasAlreadyMinted();
        }

        if (IERC20(tokenAddr).balanceOf(address(this)) < amountToMint) {
            revert InsufficientToken();
        }

        hasMinted[msg.sender] = true;
        IERC20(tokenAddr).transfer(msg.sender, amountToMint);

        return "Fast Token Successfully Minted";
    }

    /// @dev registerFastDomain function enables users to register a domain by specifying a domain name
    function registerFastDomain(string memory _domain) external {
    uint256 amountToTransfer = amountToMint;

    if (registeredDomainUsers[_domain] == true) {
        revert DomainExists();
    }

    if (registered[msg.sender] == true) {
        revert NotOwner();
    }

    if (IERC20(tokenAddr).balanceOf(address(this)) < amountToTransfer) {
        revert InsufficientToken();
    }

    if (IERC20(tokenAddr).allowance(msg.sender, address(this)) < amountToTransfer) {
        revert GetToken();
    }

    IERC20(tokenAddr).transferFrom(msg.sender, address(this), amountToTransfer);

    userNames[msg.sender] = _domain;
    registeredDomainUsers[_domain] = true;
    registered[msg.sender] = true;
    // Mint NFT and get the token ID
    uint256 nftId = nftAddr.awardUser(msg.sender);
    userNFTId[msg.sender] = nftId;

    AllRegisteredDomains.push(_domain);
    userDomains[msg.sender] = AllRegisteredDomains.length - 1; // store the index of the domain name

    emit DomainEvent(_domain, msg.sender);
    }

    function validateDomainName(string memory _domain) internal pure returns (bool) {
      // Implement your domain name validation logic here
      // This is just a simple example; modify it based on your specific requirements
      bytes memory domainBytes = bytes(_domain);
      uint256 domainLength = domainBytes.length;
      if (domainLength < 3 || domainLength > 30) {
          return false; // Invalid length
      }

      for (uint256 i = 0; i < domainLength; i++) {
          bytes1 character = domainBytes[i];
          if (
              !(character >= 0x30 && character <= 0x39) && // 0-9
              !(character >= 0x41 && character <= 0x5A) && // A-Z
              !(character >= 0x61 && character <= 0x7A) && // a-z
              !(character == 0x2D || character == 0x2E) // "-" and "."
          ) {
              return false; // Invalid character
          }
      }

      return true; // Valid domain name
    }

    /// @dev reassignDomain function allows the owner of a domain to reassign it to a new domain name
    function reassignDomain(string memory _newDomain, address user) external {
      require(validateDomainName(_newDomain), "Invalid domain name");
        if (msg.sender != user) revert NotOwner();

        if (IERC20(tokenAddr).balanceOf(msg.sender) >= amountToMint)
            revert GetToken();

        //check that user is registered
        if (registered[user] == false) revert AddressDontHaveFastDomain();

        if (registeredDomainUsers[_newDomain] == true) {
            revert DomainExists();
        }

        if (user == address(0)) {
            revert ZeroAddress();
        }

        IERC20(tokenAddr).transferFrom(msg.sender, address(this), 1e18);

        string memory oldDomain = userNames[user];
        registeredDomainUsers[oldDomain] = false;

        // update the AllRegisteredNames array using the stored index
        uint domainIndex = userDomains[user];
        AllRegisteredDomains[domainIndex] = _newDomain;

        userNames[user] = _newDomain;
        registeredDomainUsers[_newDomain] = true;

        emit DomainEvent(_newDomain, msg.sender);
    }

    /// @dev function retrieves the domain name associated with a given address
    function getDomain(
        address _domainAddress
    ) external view returns (string memory) {
        return userNames[_domainAddress];
    }

    /// @dev isDomainRegistered function checks if a domain name is already registered
    function isDomainRegistered(
        string memory domain
    ) external view returns (bool) {
        return registeredDomainUsers[domain];
    }

    /// @dev getAllregisteredDomains function returns an array containing all registered domain names.
    function getAllregisteredDomains() external view returns (string[] memory) {
        return AllRegisteredDomains;
    }
}
