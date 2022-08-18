pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A.sol";
import "./Base64.sol";

contract NFTsThatCanOwnTokens is ERC721A("", ""), ReentrancyGuard {
  using Strings for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  uint256 counter;

  mapping(uint256 => mapping(ERC20 => uint256)) public balances;
  mapping(uint256 => EnumerableSet.AddressSet) tokensInNFT;
  mapping(uint256 => uint256) public sellableAt;
  mapping(ERC20 => bool) public approvedTokens;    

  mapping(address => uint256) mintedTokens;

  modifier onlyOwnerOf(uint256 tokenId) {
    require(_exists(tokenId), "Token not in existence");
    require(msg.sender == ownerOf(tokenId), "Token not owned by caller");
    _;
  }

  modifier approvedToken(ERC20 token) {
    require(approvedTokens[token], "Not approved token");
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
    require(counter + _count < 10000, "not enough remaining!");

    _safeMint(msg.sender, _count);
    unchecked {
      counter += _count;
      mintedTokens[msg.sender] += _count;
    }
  }

  function sendTokenToNFT(uint256 tokenId, ERC20 token, uint256 amount) nonReentrant approvedToken(token) onlyOwnerOf(tokenId) public {
    require(approvedTokens[token], "not an approved token");
    require(_exists(tokenId), "token doesnt exist");
    token.transferFrom(msg.sender, address(this), amount);
    if(balances[tokenId][token] == 0) { //add to set
      tokensInNFT[tokenId].add((address(token)));
    }
    balances[tokenId][token] += amount;
  }
  function withdrawTokenFromNFT(uint256 tokenId, ERC20 token, uint256 amount) public approvedToken(token) onlyOwnerOf(tokenId) cannotSellToken(tokenId){
    require(balances[tokenId][token] >= amount, "not enough to withdraw that");
    require(amount > 0, "cannot withdraw nothing");

    token.transfer(msg.sender, amount);
    balances[tokenId][token] -= amount;
    if(balances[tokenId][token] == 0) { //add to set
      tokensInNFT[tokenId].remove((address(token)));
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
      parts = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="0x542B72"/><text x="10" y="20" class="base">';

      for (uint256 i = 0; i < tokensInNFT[tokenId].length(); i++) {
        ERC20 token = ERC20(tokensInNFT[tokenId].at(i));
        uint256 nodecimals = (balances[tokenId][token] / token.decimals());
        parts = string(abi.encodePacked(parts, "balance is ", (nodecimals == 0 ? "<1" : nodecimals.toString()), " ", token.symbol(), '</text><text x="10" y="40" class="base">'));
      }
      bool isSellable = sellableAt[tokenId] < block.timestamp;
      if(isSellable) {
        parts = string(abi.encodePacked("This token is buyable!", '</text><text x="10" y="40" class="base">'));
      } else {
        parts = string(abi.encodePacked("This token is locked and unbuyable!", '</text><text x="10" y="40" class="base">'));
      }
      string memory output = string(abi.encodePacked(parts, '</text></svg>'));

      string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "NFT Cash Card #', tokenId.toString(), ' (V1)", "description": "This NFT cash card is a fully on-chain representation of assets managed by the NFT smart contract. NFTs have balances, can be withdrawn from by the owner. It currently holds ', tokensInNFT[tokenId].length().toString(), ' types of ERC20s. It is made as a free mint to demonstrate NFT Utility.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
      output = string(abi.encodePacked('data:application/json;base64,', json));

      return output;
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
      return "NFT Cash Card v1";
    }
    function symbol() public pure override returns (string memory) {
      return "$$$";
    }
}
