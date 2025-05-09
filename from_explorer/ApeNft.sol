// SPDX-License-Identifier: MIT
pragma solidity ^0.4.18;

/* ================= SafeMath.sol ================= */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) { return 0; }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

/* ================= BasicToken.sol ================= */
contract TRC20Basic {
  function totalSupply() public constant returns (uint);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract BasicToken is TRC20Basic {
  using SafeMath for uint256;
  mapping(address => uint256) balances;
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }
}

/* ================= StandardToken.sol ================= */
contract TRC20 is TRC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract StandardToken is TRC20, BasicToken {
  mapping (address => mapping (address => uint256)) internal allowed;
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
}

/* ================= Ownable.sol ================= */
contract Ownable {
  address public owner;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  function Ownable() public {
    owner = msg.sender;
  }
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}

/* ================= Pausable.sol ================= */
contract Pausable is Ownable {
  event Pause();
  event Unpause();
  bool public paused = false;
  modifier whenNotPaused() {
    require(!paused);
    _;
  }
  modifier whenPaused() {
    require(paused);
    _;
  }
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    Pause();
  }
  function unpause() onlyOwner whenPaused public {
    paused = false;
    Unpause();
  }
}

/* ================= StandardTokenWithFees.sol ================= */
contract StandardTokenWithFees is StandardToken, Ownable {
  uint256 public basisPointsRate = 0;
  uint256 public maximumFee = 0;
  uint256 constant MAX_SETTABLE_BASIS_POINTS = 20;
  uint256 constant MAX_SETTABLE_FEE = 50;
  string public name;
  string public symbol;
  uint8 public decimals;
  uint public _totalSupply;
  uint public constant MAX_UINT = 2**256 - 1;
  function calcFee(uint _value) constant returns (uint) {
    uint fee = (_value.mul(basisPointsRate)).div(10000);
    if (fee > maximumFee) fee = maximumFee;
    return fee;
  }
  function transfer(address _to, uint _value) public returns (bool) {
    uint fee = calcFee(_value);
    uint sendAmount = _value.sub(fee);
    super.transfer(_to, sendAmount);
    if (fee > 0) super.transfer(owner, fee);
    return true;
  }
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);
    uint fee = calcFee(_value);
    uint sendAmount = _value.sub(fee);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(sendAmount);
    if (allowed[_from][msg.sender] < MAX_UINT) {
      allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    }
    Transfer(_from, _to, sendAmount);
    if (fee > 0) {
      balances[owner] = balances[owner].add(fee);
      Transfer(_from, owner, fee);
    }
    return true;
  }
}

/* ================= TimelockToken.sol ================= */
contract TimelockToken is StandardTokenWithFees {
  uint256 internal constant _DONE_TIMESTAMP = uint256(1);
  mapping(uint256 => action) public actions;
  uint256 private _minDelay = 3 days;
  uint256 public nonce;
  enum RequestType { Issue, Redeem }
  struct action {
    uint256 timestamp;
    RequestType requestType;
    uint256 value;
  }
  event RequestScheduled(uint256 indexed id, RequestType _type, uint256 value, uint256 availableTime);
  event RequestExecuted(uint256 indexed id, RequestType _type, uint256 value);
  event Issue(uint amount);
  event Redeem(uint amount);
  event Cancelled(uint256 indexed id);
  event DelayTimeChange(uint256 oldDuration, uint256 newDuration);
  constructor() public {
    emit DelayTimeChange(0, 3 days);
  }
  function isOperation(uint256 id) public view returns (bool) {
    return getTimestamp(id) > 0;
  }
  function isOperationPending(uint256 id) public view returns (bool) {
    return getTimestamp(id) > _DONE_TIMESTAMP;
  }
  function isOperationReady(uint256 id) public view returns (bool) {
    uint256 timestamp = getTimestamp(id);
    return timestamp > _DONE_TIMESTAMP && timestamp <= block.timestamp;
  }
  function isOperationDone(uint256 id) public view returns (bool) {
    return getTimestamp(id) == _DONE_TIMESTAMP;
  }
  function getTimestamp(uint256 id) public view returns (uint256 timestamp) {
    return actions[id].timestamp;
  }
  function getMinDelay() public view returns (uint256) {
    return _minDelay;
  }
  function _request(RequestType _requestType, uint256 value) private {
    uint256 id = nonce;
    nonce++;
    _schedule(id, _requestType, value, _minDelay);
  }
  function _schedule(uint256 id, RequestType _type, uint256 value, uint256 delay) private {
    require(!isOperation(id), "already scheduled");
    require(delay >= getMinDelay(), "insufficient delay");
    uint256 availableTime = block.timestamp + delay;
    actions[id].timestamp = availableTime;
    actions[id].requestType = _type;
    actions[id].value = value;
    emit RequestScheduled(id, _type, value, availableTime);
  }
  function cancel(uint256 id) public onlyOwner {
    require(isOperationPending(id), "cannot be cancelled");
    delete actions[id];
    emit Cancelled(id);
  }
  function _beforeCall(uint256 id) private {
    require(isOperation(id), "not registered");
  }
  function _afterCall(uint256 id) private {
    require(isOperationReady(id), "not ready");
    actions[id].timestamp = _DONE_TIMESTAMP;
  }
  function _call(uint256 id, address owner) private {
    uint256 amount = actions[id].value;
    if (actions[id].requestType == RequestType.Issue) {
      balances[owner] = balances[owner].add(amount);
      _totalSupply = _totalSupply.add(amount);
      emit Transfer(address(0), owner, amount);
      emit Issue(amount);
    } else {
      _totalSupply = _totalSupply.sub(amount);
      balances[owner] = balances[owner].sub(amount);
      emit Transfer(owner, address(0), amount);
      emit Redeem(amount);
    }
  }
  function requestIssue(uint256 amount) public onlyOwner {
    _request(RequestType.Issue, amount);
  }
  function requestRedeem(uint256 amount) public onlyOwner {
    _request(RequestType.Redeem, amount);
  }
  function executeRequest(uint256 id) public onlyOwner {
    _beforeCall(id);
    _call(id, msg.sender);
    _afterCall(id);
  }
}

/* ================= APENFT.sol ================= */
contract UpgradedStandardToken is StandardToken {
  uint public _totalSupply;
  function transferByLegacy(address from, address to, uint value) public returns (bool);
  function transferFromByLegacy(address sender, address from, address spender, uint value) public returns (bool);
  function approveByLegacy(address from, address spender, uint value) public returns (bool);
  function increaseApprovalByLegacy(address from, address spender, uint addedValue) public returns (bool);
  function decreaseApprovalByLegacy(address from, address spender, uint subtractedValue) public returns (bool);
}

contract APENFT is Pausable, TimelockToken {
  address public upgradedAddress;
  bool public deprecated;
  function APENFT() public {
    _totalSupply = 999990000000000000000;
    name = "APENFT";
    symbol = "NFT";
    decimals = 6;
    balances[owner] = _totalSupply;
    emit Transfer(address(0), msg.sender, _totalSupply);
    deprecated = false;
  }
  function transfer(address _to, uint _value) public whenNotPaused returns (bool) {
    if (deprecated) {
      return UpgradedStandardToken(upgradedAddress).transferByLegacy(msg.sender, _to, _value);
    } else {
      return super.transfer(_to, _value);
    }
  }
  function transferFrom(address _from, address _to, uint _value) public whenNotPaused returns (bool) {
    if (deprecated) {
      return UpgradedStandardToken(upgradedAddress).transferFromByLegacy(msg.sender, _from, _to, _value);
    } else {
      return super.transferFrom(_from, _to, _value);
    }
  }
  function balanceOf(address who) public constant returns (uint) {
    if (deprecated) {
      return UpgradedStandardToken(upgradedAddress).balanceOf(who);
    } else {
      return super.balanceOf(who);
    }
  }
  function oldBalanceOf(address who) public constant returns (uint) {
    if (deprecated) {
      return super.balanceOf(who);
    }
  }
  function approve(address _spender, uint _value) public whenNotPaused returns (bool) {
    if (deprecated) {
      return UpgradedStandardToken(upgradedAddress).approveByLegacy(msg.sender, _spender, _value);
    } else {
      return super.approve(_spender, _value);
    }
  }
  function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool) {
    if (deprecated) {
      return UpgradedStandardToken(upgradedAddress).increaseApprovalByLegacy(msg.sender, _spender, _addedValue);
    } else {
      return super.increaseApproval(_spender, _addedValue);
    }
  }
  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool) {
    if (deprecated) {
      return UpgradedStandardToken(upgradedAddress).decreaseApprovalByLegacy(msg.sender, _spender, _subtractedValue);
    } else {
      return super.decreaseApproval(_spender, _subtractedValue);
    }
  }
  function allowance(address _owner, address _spender) public constant returns (uint remaining) {
    if (deprecated) {
      return StandardToken(upgradedAddress).allowance(_owner, _spender);
    } else {
      return super.allowance(_owner, _spender);
    }
  }
  function deprecate(address _upgradedAddress) public onlyOwner {
    require(_upgradedAddress != address(0));
    deprecated = true;
    upgradedAddress = _upgradedAddress;
    Deprecate(_upgradedAddress);
  }
  function totalSupply() public constant returns (uint) {
    if (deprecated) {
      return StandardToken(upgradedAddress).totalSupply();
    } else {
      return _totalSupply;
    }
  }
  event Deprecate(address newAddress);
}

/* ================= Migrations.sol ================= */
contract Migrations {
  address public owner;
  uint public last_completed_migration;
  modifier restricted() { if (msg.sender == owner) _; }
  function Migrations() public { owner = msg.sender; }
  function setCompleted(uint completed) public restricted { last_completed_migration = completed; }
  function upgrade(address newAddress) public restricted {
    Migrations upgraded = Migrations(newAddress);
    upgraded.setCompleted(last_completed_migration);
  }
}

/* ================= MultiSigWallet.sol ================= */
contract MultiSigWallet {
  uint constant public MAX_OWNER_COUNT = 50;
  event Confirmation(address indexed sender, uint indexed transactionId);
  event Revocation(address indexed sender, uint indexed transactionId);
  event Submission(uint indexed transactionId);
  event Execution(uint indexed transactionId);
  event ExecutionFailure(uint indexed transactionId);
  event Deposit(address indexed sender, uint value);
  event OwnerAddition(address indexed owner);
  event OwnerRemoval(address indexed owner);
  event RequirementChange(uint required);

  mapping (uint => Transaction) public transactions;
  mapping (uint => mapping (address => bool)) public confirmations;
  mapping (address => bool) public isOwner;
  address[] public owners;
  uint public required;
  uint public transactionCount;

  struct Transaction {
    address destination;
    uint value;
    bytes data;
    bool executed;
  }

  modifier onlyWallet() {
    if (msg.sender != address(this)) throw;
    _;
  }
  modifier ownerDoesNotExist(address owner) {
    if (isOwner[owner]) throw;
    _;
  }
  modifier ownerExists(address owner) {
    if (!isOwner[owner]) throw;
    _;
  }
  modifier transactionExists(uint transactionId) {
    if (transactions[transactionId].destination == 0) throw;
    _;
  }
  modifier confirmed(uint transactionId, address owner) {
    if (!confirmations[transactionId][owner]) throw;
    _;
  }
  modifier notConfirmed(uint transactionId, address owner) {
    if (confirmations[transactionId][owner]) throw;
    _;
  }
  modifier notExecuted(uint transactionId) {
    if (transactions[transactionId].executed) throw;
    _;
  }
  modifier notNull(address _address) {
    if (_address == 0) throw;
    _;
  }
  modifier validRequirement(uint ownerCount, uint _required) {
    if (
      ownerCount > MAX_OWNER_COUNT ||
      _required > ownerCount ||
      _required == 0 ||
      ownerCount == 0
    ) throw;
    _;
  }

  function() payable { if (msg.value > 0) Deposit(msg.sender, msg.value); }

  function MultiSigWallet(address[] _owners, uint _required)
    public validRequirement(_owners.length, _required)
  {
    for (uint i = 0; i < _owners.length; i++) {
      if (isOwner[_owners[i]] || _owners[i] == 0) throw;
      isOwner[_owners[i]] = true;
    }
    owners = _owners;
    required = _required;
  }

  function addOwner(address owner)
    public onlyWallet ownerDoesNotExist(owner) notNull(owner)
    validRequirement(owners.length + 1, required)
  {
    isOwner[owner] = true;
    owners.push(owner);
    OwnerAddition(owner);
  }

  function removeOwner(address owner)
    public onlyWallet ownerExists(owner)
  {
    isOwner[owner] = false;
    for (uint i = 0; i < owners.length - 1; i++)
      if (owners[i] == owner) {
        owners[i] = owners[owners.length - 1];
        break;
      }
    owners.length -= 1;
    if (required > owners.length) changeRequirement(owners.length);
    OwnerRemoval(owner);
  }

  function replaceOwner(address owner, address newOwner)
    public onlyWallet ownerExists(owner) ownerDoesNotExist(newOwner)
  {
    for (uint i = 0; i < owners.length; i++)
      if (owners[i] == owner) {
        owners[i] = newOwner;
        break;
      }
    isOwner[owner] = false;
    isOwner[newOwner] = true;
    OwnerRemoval(owner);
    OwnerAddition(newOwner);
  }

  function changeRequirement(uint _required)
    public onlyWallet validRequirement(owners.length, _required)
  {
    required = _required;
    RequirementChange(_required);
  }

  function submitTransaction(address destination, uint value, bytes data)
    public returns (uint transactionId)
  {
    transactionId = addTransaction(destination, value, data);
    confirmTransaction(transactionId);
  }

  function confirmTransaction(uint transactionId)
    public ownerExists(msg.sender) transactionExists(transactionId)
    notConfirmed(transactionId, msg.sender)
  {
    confirmations[transactionId][msg.sender] = true;
    Confirmation(msg.sender, transactionId);
    executeTransaction(transactionId);
  }

  function revokeConfirmation(uint transactionId)
    public ownerExists(msg.sender) confirmed(transactionId, msg.sender) notExecuted(transactionId)
  {
    confirmations[transactionId][msg.sender] = false;
    Revocation(msg.sender, transactionId);
  }

  function executeTransaction(uint transactionId)
    public notExecuted(transactionId)
  {
    if (isConfirmed(transactionId)) {
      Transaction storage tx = transactions[transactionId];
      tx.executed = true;
      if (tx.destination.call.value(tx.value)(tx.data))
        Execution(transactionId);
      else {
        ExecutionFailure(transactionId);
        tx.executed = false;
      }
    }
  }

  function isConfirmed(uint transactionId) public constant returns (bool) {
    uint count = 0;
    for (uint i = 0; i < owners.length; i++) {
      if (confirmations[transactionId][owners[i]]) count += 1;
      if (count == required) return true;
    }
  }

  function addTransaction(address destination, uint value, bytes data)
    internal notNull(destination) returns (uint transactionId)
  {
    transactionId = transactionCount;
    transactions[transactionId] = Transaction({ destination: destination, value: value, data: data, executed: false });
    transactionCount += 1;
    Submission(transactionId);
  }

  function getConfirmationCount(uint transactionId) public constant returns (uint count) {
    for (uint i = 0; i < owners.length; i++)
      if (confirmations[transactionId][owners[i]]) count += 1;
  }

  function getTransactionCount(bool pending, bool executed) public constant returns (uint count) {
    for (uint i = 0; i < transactionCount; i++)
      if ( (pending && !transactions[i].executed) || (executed && transactions[i].executed) ) count += 1;
  }

  function getOwners() public constant returns (address[]) {
    return owners;
  }

  function getConfirmations(uint transactionId) public constant returns (address[]) {
    address[] memory confirmationsTemp = new address[](owners.length);
    uint count = 0;
    for (uint i = 0; i < owners.length; i++)
      if (confirmations[transactionId][owners[i]]) {
        confirmationsTemp[count] = owners[i];
        count += 1;
      }
    address[] memory _confirmations = new address[](count);
    for (uint i = 0; i < count; i++) {
      _confirmations[i] = confirmationsTemp[i];
    }
    return _confirmations;
  }

  function getTransactionIds(uint from, uint to, bool pending, bool executed)
    public constant returns (uint[]) {
    uint[] memory transactionIdsTemp = new uint[](transactionCount);
    uint count = 0;
    for (uint i = 0; i < transactionCount; i++)
      if ( (pending && !transactions[i].executed) || (executed && transactions[i].executed) ) {
        transactionIdsTemp[count] = i;
        count += 1;
      }
    uint[] memory _transactionIds = new uint[](to - from);
    for (uint j = from; j < to; j++) {
      _transactionIds[j - from] = transactionIdsTemp[j];
    }
    return _transactionIds;
  }
}
