pragma solidity ^0.4.23;

import './ERC20/MintableToken.sol';
import '../ownership/Ownable.sol';

contract ERC20TokenMain is MintableToken{
  using SafeMath for uint256;
  // FIELDS
  string public name = "ToBeDecided";
  string public symbol = "TBD";
  uint256 public decimals = 18;
  bool public tradable = false;

  modifier isTradable {
    require(tradable);
    _;
  }

  // prevent transfers until trading allowed
  function transfer(address _to, uint256 _value) public isTradable returns (bool success) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public
  isTradable returns (bool) {
    return super.transferFrom(_from,_to,_value);
  }

  function approve(address _spender, uint256 _value) public isTradable returns (bool) {
    return super.approve(_spender,_value);
  }
}
