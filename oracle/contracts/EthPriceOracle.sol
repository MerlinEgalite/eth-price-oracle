pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./CallerContractInterface.sol";

contract EthPriceOracle is AccessControl {

  using SafeMath for uint256;
  struct Response {
    address oracleAddress;
    address callerAddress;
    uint256 ethPrice;
  }

  bytes32 private constant OWNER_ROLE = keccak256('OWNER_ROLE');
  bytes32 private constant ORACLE_ROLE = keccak256('ORACLE_ROLE');

  uint private randNonce = 0;
  uint private modulus = 1000;
  uint private numOracles = 0;
  uint private THRESHOLD = 0;
  mapping(uint256 => bool) pendingRequests;
  mapping (uint256 => Response[]) public requestIdToResponse;

  event GetLatestEthPriceEvent(address callerAddress, uint id);
  event SetLatestEthPriceEvent(uint256 ethPrice, address callerAddress);
  event AddOracleEvent(address oracleAddress);
  event RemoveOracleEvent(address oracleAddress);

  constructor (address _owner) public {
    grantRole(keccak256("DEFAULT_ADMIN_ROLE"), msg.sender);
  }

  function addOracle (address _oracle) public {
    require(hasRole(OWNER_ROLE, msg.sender), "Not an owner!");
    require(!hasRole(ORACLE_ROLE, _oracle), "Already an oracle!");
    grantRole(ORACLE_ROLE, _oracle);
    numOracles++;
    emit AddOracleEvent(_oracle);
  }

  function removeOracle (address _oracle) public {
    require(hasRole(OWNER_ROLE, msg.sender), "Not an owner!");
    require(!hasRole(ORACLE_ROLE, _oracle), "Already an oracle!");
    require(numOracles > 1, "Do not remove the last oracle!");
    revokeRole(ORACLE_ROLE, _oracle);
    numOracles--;
    emit RemoveOracleEvent(_oracle);
  }

	function getLatestEthPrice () public returns(uint256) {
		randNonce++;
		uint id = uint(keccak256(abi.encodePacked(now, msg.sender, randNonce))) % modulus;
		pendingRequests[id] = true;
    emit GetLatestEthPriceEvent(msg.sender, id);
    return id;
  }

	function setLatestEthPrice (uint256 _ethPrice, address _callerAddress, uint256 _id) public {
    require(hasRole(ORACLE_ROLE, msg.sender), "Not an oracle!");
    require(pendingRequests[_id], "This request is not in my pending list.");
    Response memory resp;
    resp = Response(msg.sender, _callerAddress, _ethPrice);
    requestIdToResponse[_id].push(resp);
    uint numResponses = requestIdToResponse[_id].length;
    if (numResponses == THRESHOLD) {
      uint computedEthPrice = 0;
        for (uint i=0; i < requestIdToResponse[_id].length; i++) {
        computedEthPrice = computedEthPrice.add(requestIdToResponse[_id][i].ethPrice);
      }
      computedEthPrice = computedEthPrice.div(numResponses);
      delete pendingRequests[_id];
      delete requestIdToResponse[_id];
      CallerContractInterface callerContractInstance;
      callerContractInstance = CallerContractInterface(_callerAddress);
      callerContractInstance.callback(computedEthPrice, _id);
      emit SetLatestEthPriceEvent(computedEthPrice, _callerAddress);
    }
  }
}
