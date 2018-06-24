pragma solidity ^0.4.23;

import './token/ERC20/ERC20.sol';
import './ownership/CanReclaimToken.sol';
import './token/ERC20TokenMain.sol';

contract AllocateERC20Tokens is ERC20TokenMain,CanReclaimToken{
  event Unmint(address indexed to, uint256 amount);
  event Tradable(uint256 timeStamp);
  using SafeMath for uint;
  uint constant D160 = 0x10000000000000000000000000000000000000000;

  address public vestingContract;
  bool public vestingDeployed;

  // Track allocation completion status.
  bool public allocationsComplete = false;
  uint256 allocatedAccounts;

  function setVestingContract(address _vestingContract) external onlyOwner
  {
    require(_vestingContract != address(0));
    vestingContract = _vestingContract;
    vestingDeployed = true;
  }

  // Number of accounts to be processed per batch.
  uint256 public batchAllocateLimit = 100;

  function updateBatchAllocationLimit(uint256 _batchLimit) public onlyOwner{
    require(_batchLimit > 0);
    batchAllocateLimit = _batchLimit;
  }


  modifier canAllocate(){
    require(!allocationsComplete);
    _;
  }

  /* The 160 LSB is the address of the balance
   * The 96 MSB is the balance of that address.
   * Batch allocate tokens to unallocated address.
   * Assumption: The tokens to assign have been calculated offchain with the
   * relevant currency rates after deducting legal and marketing fees.
   * @param {array} Packed uint256 array consisting of balance and token count.
   */
  function batchAllocate(uint[] data) external onlyOwner canAllocate{
    require(data.length <= batchAllocateLimit );

    for (uint i=0; i<data.length; i++) {
      address investor = address( data[i] & (D160-1) );
      uint tokenCount = data[i] / D160;
      allocateTokens(investor,tokenCount);
    }
  }

  function batchOverWriteAllocation(uint[] data) external onlyOwner canAllocate{
    require(data.length <= batchAllocateLimit);

    for (uint i=0; i<data.length; i++) {
      address investor = address( data[i] & (D160-1) );
      uint tokenCount = data[i] / D160;
        overwriteAllocation(investor,tokenCount);
    }
  }

  /* Allocate tokens to new addresses.
   * Note: Does not allocate to existing addresses, use overwrite instead
   * @params {address} investor
   * @params {uint256} tokenCount - Number of tokens to allocate
   */
  function allocateTokens(address investor, uint256 tokenCount) public onlyOwner canAllocate
  {
    // Don't allocate tokens if address already exists
    require(investor != address(0));
    require(balances[investor] == 0);
    require(tokenCount > 0);
    allocatedAccounts++;
    mint(investor,tokenCount);
  }

  function overwriteAllocation(address _to,uint256 _overWriteAmount) public onlyOwner canAllocate
  {
    // Ensure if the _to addess is already allocated.
    require(balances[_to] != 0);
    uint256 delta;
    uint256 existingBalance = balances[_to];
    if (existingBalance > _overWriteAmount){
      //Subtract
      delta = existingBalance.sub(_overWriteAmount);
      balances[_to] = balances[_to].sub(delta);
      totalSupply_ = totalSupply_.sub(delta);
      emit Unmint(_to,delta);
    }else{
      //Add
      delta = _overWriteAmount.sub(existingBalance);
      mint(_to,delta);
    }
  }

  /* Mark allocations as completed.
   * Flippable safety switch to prevent accidental sealing and vesting allocation.
   * Required for vesting allocation.
   */
  function markAllocationsAsComplete() public onlyOwner{
    require(!allocationsComplete);
    allocationsComplete = true;
  }

  // Mark allocations as incomplete.
  // Flip the flag the other way.
  function markAllocationsAsIncomplete() public onlyOwner{
    require(allocationsComplete);
    allocationsComplete = false;
  }

  function setTradable() external onlyOwner{
    require(vestingDeployed);
    tradable = true;
    emit Tradable(now);
  }

  /* Can be called only once
   * Mints tokens to vesting contract
   * Expected to be called after allocation of all tokens to investors.
   * 'Seals' the contract to prevent further minting and thereyby allocation of
   * tokens.
   */
  function finishMintingAndSeal() external onlyOwner canMint returns (bool){
    require(allocationsComplete);
    require(totalSupply_ > 0);
    require(vestingDeployed);
		mint(vestingContract,totalSupply_.mul(35).div(1000));
    return finishMinting();
  }
}
