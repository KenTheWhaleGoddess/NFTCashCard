pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A.sol";
import "./Base64.sol";

contract NFTsThatCanOwnTokens is ERC721A("NFT Cash Card V1", "$$$"), Ownable, ReentrancyGuard {
  using Strings for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  uint256 counter;

  mapping(uint256 => mapping(ERC20 => uint256)) balances;
  mapping(uint256 => EnumerableSet.AddressSet) tokensInNFT;
  mapping(uint256 => uint256) withdrawableAt;
  mapping(ERC20 => bool) approvedTokens;    

  modifier onlyOwnerOf(uint256 tokenId) {
    require(_exists(tokenId), "Token not in existence");
    require(msg.sender == ownerOf(tokenId), "Token not owned by caller");
    _;
  }

  modifier approvedToken(ERC20 token) {
    require(approvedTokens[token], "Not approved");
    _;
  }
  modifier withdrawableToken(uint256 tokenId) {
    require(withdrawableAt[tokenId] > block.timestamp, "Not approved");
    _;
  }
  modifier notWithdrawableToken(uint256 tokenId) {
    require(withdrawableAt[tokenId] < block.timestamp, "Not approved");
    _;
  }

  // public
  function mint(uint256 _count) public {
    require(_count < 11, "10 is the max at a time");
    require(counter + _count < 10000, "not enough remaining!");

    _safeMint(msg.sender, _count);
    counter += _count;
  }

  function sendTokenToNFT(uint256 tokenId, ERC20 token, uint256 amount) nonReentrant approvedToken(token) onlyOwnerOf(tokenId) public {
    require(token.allowance(msg.sender, address(token)) >= amount, "Not approved to spend");
    require(approvedTokens[token], "not an approved token");
    token.transferFrom(msg.sender, address(this), amount);
    if(balances[tokenId][token] == 0) { //add to set
      tokensInNFT[tokenId].add((address(token)));
    }
    balances[tokenId][token] += amount;
  }
  function withdrawTokenFromNFT(uint256 tokenId, ERC20 token, uint256 amount) public approvedToken(token) onlyOwnerOf(tokenId) {
    require(balances[tokenId][token] >= amount, "not enough to withdraw that");
    require(amount > 0, "cannot withdraw nothing");
    require(withdrawableAt[tokenId] > block.timestamp, "token not withdrawable yet");

    token.transfer(msg.sender, amount);
    balances[tokenId][token] -= amount;
    if(balances[tokenId][token] == 0) { //add to set
      tokensInNFT[tokenId].remove((address(token)));
    }
  }

  function startWithdrawableTimer(uint256 tokenId) external onlyOwnerOf(tokenId) {
    withdrawableAt[tokenId] = block.timestamp + 7 days;
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
          parts = string(abi.encodePacked(parts, "balance is ", (balances[tokenId][token] / token.decimals()).toString(), " ", token.symbol(), '</text><text x="10" y="40" class="base">'));
        }

        string memory output = string(abi.encodePacked(parts, '</text></svg>'));

        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "NFT Cash Card #', tokenId.toString(), ' (V1)", "description": "This NFT cash card is a fully on-chain representation of assets managed by the NFT smart contract. NFTs have balances, can be withdrawn from by the owner. It currently holds ', tokensInNFT[tokenId].length().toString(), ' types of ERC20s. It is made as a free mint to demonstrate NFT Utility.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));

        return output;
    }

    function toggleApprovedToken(address _token) external onlyOwner {
      ERC20 token = ERC20(_token);
      approvedTokens[token] = !approvedTokens[token];
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override withdrawableToken(tokenId) {
      return super.safeTransferFrom(from, to, tokenId);
    }
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override withdrawableToken(tokenId) {
      return super.safeTransferFrom(from, to, tokenId, data);
    }
    function transferFrom(address from, address to, uint256 tokenId) public override withdrawableToken(tokenId) {
      return super.transferFrom(from, to, tokenId);
    }
}
