pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A.sol";
import "./Base64.sol";

contract NFTsThatCanOwnTokens is ERC721A("", ""), ReentrancyGuard {
  using Strings for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  uint256 counter;

  mapping(uint256 => mapping(ERC20 => uint256)) public balances;
  mapping(uint256 => uint256) public ethBalances;
  mapping(uint256 => EnumerableSet.AddressSet) tokensInNFT;
  mapping(uint256 => uint256) public sellableAt;
  mapping(ERC20 => bool) public approvedTokens;    

  uint256 public maxNftSupply;

  mapping(address => uint256) mintedTokens;

  modifier onlyOwnerOf(uint256 tokenId) {
    require(_exists(tokenId), "Token not in existence");
    require(msg.sender == ownerOf(tokenId), "Token not owned by caller");
    _;
  }

  modifier cannotSellToken(uint256 tokenId) {
    require(sellableAt[tokenId] == 0 || sellableAt[tokenId] > block.timestamp, "can send/sell token!");
    _;
  }
  modifier canSellToken(uint256 tokenId) {
    require(sellableAt[tokenId] > 0 && sellableAt[tokenId] < block.timestamp, "Cannot send/sell token yet!");
    _;
  }

  // public
  function mint(uint256 _count) public {
    require(mintedTokens[msg.sender] + _count < 11, "10 is the max at a time");
    require(counter + _count <= maxNftSupply, "not enough remaining!");

    _safeMint(msg.sender, _count);
    unchecked {
      counter += _count;
      mintedTokens[msg.sender] += _count;
    }
  }

  function sendTokensToNFT(uint256 tokenId, ERC20[] calldata tokens, uint256[] calldata amounts) nonReentrant public payable {
    require(_exists(tokenId), "token doesnt exist");
    for(uint256 i = 0; i < tokens.length; i++) {  
      require(approvedTokens[tokens[i]], "not an approved token");
      tokens[i].transferFrom(msg.sender, address(this), amounts[i]);
      if(balances[tokenId][tokens[i]] == 0) { //add to set
        tokensInNFT[tokenId].add((address(tokens[i])));
      }
      balances[tokenId][tokens[i]] += amounts[i];
    }
    if(msg.value > 0) {
      ethBalances[tokenId] += msg.value;
    }
  }
  function withdrawTokensFromNFT(uint256 tokenId, ERC20[] calldata tokens, uint256[] calldata amounts, uint256 ethAmount, address _receiver) public onlyOwnerOf(tokenId) cannotSellToken(tokenId){
    require(_receiver != address(0));
    for(uint256 i = 0; i < tokens.length; i++) {
      uint256 amount = amounts[i];
      require(balances[tokenId][tokens[i]] >= amount, "not enough to withdraw that");
      require(amount > 0, "cannot withdraw nothing");

      tokens[i].transfer(_receiver, amount);
      balances[tokenId][tokens[i]] -= amount;
      if(balances[tokenId][tokens[i]] == 0) { //add to set
        tokensInNFT[tokenId].remove((address(tokens[i])));
      }
    }
    if(ethAmount > 0) {
      require(ethBalances[tokenId] >= ethAmount, "taking out too much");
      ethBalances[tokenId] -= ethAmount;
    }
   }

  function enableSelling(uint256 tokenId) external onlyOwnerOf(tokenId) {
    sellableAt[tokenId] = block.timestamp + 3 hours;
  }

  function cancelSelling(uint256 tokenId) external onlyOwnerOf(tokenId) {
    sellableAt[tokenId] = 0;
  }
  
  function balanceOfAt(uint256 tokenId, ERC20 token) public view returns (uint256) {
    return balances[tokenId][token];
  } 

  function tokenURI(uint256 tokenId) override public view returns (string memory) {
      require(_exists(tokenId),"ERC721Metadata: URI query for nonexistent token");
      string memory parts;
      bool isSellable = sellableAt[tokenId] > 0 && sellableAt[tokenId] < block.timestamp;
      string memory color;
      if (isSellable) {
        color = string(abi.encodePacked("#4e9", (uint256(keccak256(abi.encodePacked(tokenId, "asdf"))) % 1000).toString()));
      } else {
        color = "#923c31";
      }
      parts = string(abi.encodePacked('<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="',color,'"/><text x="10" y="20" class="base">'));
      uint256 nodecimals = (ethBalances[tokenId] / 10**18);
      uint256 decimals = (ethBalances[tokenId] % 10**18/ 10**16);

      parts = string(abi.encodePacked(parts, "ETH balance is ", nodecimals.toString(), '.', decimals.toString(), '</text><text x="10" y="40" class="base">'));

      for (uint256 i = 0; i < tokensInNFT[tokenId].length(); i++) {
        ERC20 token = ERC20(tokensInNFT[tokenId].at(i));
        uint256 nodecimals = (balances[tokenId][token] / 10**18);
        uint256 decimals = ((balances[tokenId][token] % 10**18 )/ 10**16);
        parts = string(abi.encodePacked(parts, "balance is ", (nodecimals == 0 ? "<1" : nodecimals.toString()), " ", token.symbol(), '</text><text x="10" y="40" class="base">'));
      }
      if(isSellable) {
        parts = string(abi.encodePacked(parts, "This token is buyable!", '</text></svg>'));
      } else {
        parts = string(abi.encodePacked(parts, "This token is locked and unbuyable!", '</text></svg>'));
      }

      string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Crypto Cash Card #', tokenId.toString(), ' (V1)", "description": "This NFT cash card is a fully on-chain representation of assets managed by the NFT smart contract. NFTs have balances, can be withdrawn from by the owner. It currently holds ', tokensInNFT[tokenId].length().toString(), ' types of ERC20s. It is made as a free mint to demonstrate NFT Utility.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(parts)), '"}'))));
      string memory output = string(abi.encodePacked('data:application/json;base64,', json));

      return output;
  }

  receive() external payable {
    revert('dont send eth');
  }

  function getTokensInNFT(uint256 tokenId) external view returns (address[] memory result) {
    for(uint256 i = 0; i < tokensInNFT[tokenId].length(); i++) {
      result[i] = (tokensInNFT[tokenId].at(i));
    }
  }

  function toggleApprovedToken(address _token) external {
    require(msg.sender == 0x1B3FEA07590E63Ce68Cb21951f3C133a35032473, "not approver");
    ERC20 token = ERC20(_token);
    approvedTokens[token] = !approvedTokens[token];
  }
  function setMaxNftSupply(uint256 supply) external {
    //require(msg.sender == 0x1B3FEA07590E63Ce68Cb21951f3C133a35032473, "not approver");
    require(supply > totalSupply(), "too low");
    maxNftSupply = supply;
  }

  function safeTransferFrom(address from, address to, uint256 tokenId) public override canSellToken(tokenId) {
    return super.safeTransferFrom(from, to, tokenId);
  }
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override canSellToken(tokenId) {
    return super.safeTransferFrom(from, to, tokenId, data);
  }
  function transferFrom(address from, address to, uint256 tokenId) public override canSellToken(tokenId) {
    return super.transferFrom(from, to, tokenId);
  }

  function name() public pure override returns (string memory) {
    return "Crypto Cash Card v1";
  }
  function symbol() public pure override returns (string memory) {
    return "$$$";
  }
}
