// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MultiSig {

    // events
    event Deposit(address indexed sender, uint amount);
    event Submit(address indexed owner, uint indexed txId);
    event Approve(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    // Transaction "class"
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    // array of multisig signers
    address[] public owners;
    // mapping to find out if address is an owner/signer
    mapping(address => bool) public isOwner;
    // # of signatures required to execute
    uint public signaturesRequired;

    // From meta multisig contract
/*     uint public nonce;
    uint public chainId; */

    // array of transactions for owners to sign
    Transaction[] public transactions;
    // double mapping - txId -> address -> bool
    mapping(uint => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!approved[_txId][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint _signaturesRequired) {
        require(_owners.length > 0, "Need owners to deploy");
        require(_signaturesRequired > 0 && _signaturesRequired <= _owners.length, "constructor: parameter of owners not met");

        for (uint i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner is not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        signaturesRequired = _signaturesRequired;
    }

    receive() external payable{
        emit Deposit(msg.sender, msg.value);
    }

    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));
        emit Submit(msg.sender, transactions.length -1);
    }

    function approve(uint _txId) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId){
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint _txId) private view returns (uint count) {
        for (uint i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

    function execute(uint _txId) external txExists(_txId) notExecuted(_txId) {
        require(_getApprovalCount(_txId) >= signaturesRequired, "approvals < required");
        Transaction storage transaction = transactions[_txId];

        transaction.executed = true;
        
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit Execute(_txId);
    }

    function revoke(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "tx not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}