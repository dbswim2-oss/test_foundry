// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract VaultMultisig {

    /// @notice The number of signatures required to execute a transaction
    uint256 public quorum;

    /// @notice  The number of transfers that have been created
    uint256 public transfersCount;

    /// @notice The struct of a transfer
    /// @param to The address of the recipient
    /// @param amount The amount of ether to be sent
    /// @param approvals The number of approvals for the transfer
    /// @param executed Whether the transfer has been executed or not
    /// @param approved The mapping of signers to their approval status for the transfer 
    struct Transfer {
        address to;
        uint256 amount;
        uint256 approvals;
        bool executed;
        mapping(address => bool) approved;
    }

    /// @notice The mapping of transfer IDs to their corresponding Transfer struct
    mapping(uint256 => Transfer) private transfers;

    /// @notice The mapping for verification that address is a signer
    mapping(address => bool) private multiSigSigners;

    /// @notice Check that the signers array is not empty
    error SignersArrayCannotBeEmpty();

    /// @notice Check if quorum is not greater than number of signers length
    error QuorumGreaterThanSigners();

    /// @notice Check that quorum is greater than zero
    error QuorumCannotBeZero();

    /// @notice Check that recipient address is not zero address
    error InvalidRecipient();

    /// @notice Check that amount is greater than zero
    error InvalidAmount();

    /// @notice Check that the signer is valid
    error InvalidMultiSigSigner();

    /// @notice Check that the transfer has not already been executed
    /// @param transferId The ID of the transfer
    error TransferIsAlreadyExecuted(uint256 transferId);

    /// @notice Check that the transfer has been approved by enough signers
    /// @param transferId The ID of the transfer
    error TransferNotApproved(uint256 transferId);

    /// @notice Check that the quorum has not been reached
    /// @param transferId The ID of the transfer
    error QuorumHasNotBeenReached(uint256 transferId);

    /// @notice Check that the contract has enough balance to execute the transfer
    /// @param balance The current balance of the contract
    /// @param amount The amount of ether to be sent
    error IncufficientBalance(uint256 balance, uint256 amount);

    /// @notice Check that the transfer has been executed successfully
    /// @param transferId The ID of the transfer
    error TransferFailed(uint256 transferId);

    /// @notice Check that the signer has not already approved the transfer
    /// @param signer The address of the signer
    error SignerAlreadyApproved(address signer);

    /// @notice Check that the contract has enough balance to execute the transfer
    /// @param balance The current balance of the contract
    /// @param amount The amount of ether to be sent
    error InsufficientBalance(uint256 balance, uint256 amount);

    /// @notice Emmited when a transfer is initiated
    /// @param transferId The ID of the transfer
    /// @param to The address of the recipient
    /// @param amount The amount of ether to be sent
    event TransferInitiated(uint256 indexed transferId, address indexed to, uint256 amount);

    /// @notice Emmited when a transfer is approved
    /// @param transferId The ID of the transfer
    /// @param signer The address of the signer
    event TransferApproved(uint256 indexed transferId, address indexed signer);

    /// @notice Emmited when a transfer is executed
    /// @param transferId The ID of the transfer
    event TransferExecuted(uint256 indexed transferId);

    modifier onlyMultiSigSigners() {
        if (!multiSigSigners[msg.sender]) revert InvalidMultiSigSigner();
        _;
    }

    /// @notice Initialize the contract with the signers and quorum
    /// @param _signers The array of signers for the multisig wallet
    /// @param _quorum The number of signatures required to execute a transaction
    constructor(address[] memory _signers, uint256 _quorum) {
        if (_signers.length == 0) revert SignersArrayCannotBeEmpty();
        if (_quorum > _signers.length) revert QuorumGreaterThanSigners();
        if (_quorum == 0) revert QuorumCannotBeZero();

        for (uint256 i = 0; i < _signers.length; i++) {
            multiSigSigners[_signers[i]] = true;
        }
        quorum = _quorum;
    }

    /// @notice Initiate a transfer to a recipient address with a specified amount
    /// @param _to The address of the recipient
    /// @param _amount The amount of ether to be sent
    function initiateTransfer(address _to, uint256 _amount) external onlyMultiSigSigners {
        if (_to == address(0)) revert InvalidRecipient();
        if (_amount == 0) revert InvalidAmount();

        uint256 transferId = transfersCount++;
        Transfer storage transfer = transfers[transferId];
        transfer.to = _to;
        transfer.amount = _amount;
        transfer.approvals = 0;
        transfer.executed = false;
        transfer.approved[msg.sender] = true;

        emit TransferInitiated(transferId, _to, _amount);
    }

    function approveTransfer(uint256 _transferId) external onlyMultiSigSigners {
         Transfer storage transfer = transfers[_transferId];
        if (transfer.executed) revert TransferIsAlreadyExecuted(_transferId);
        if (transfer.approved[msg.sender]) revert SignerAlreadyApproved(msg.sender);

        transfer.approvals++;
        transfer.approved[msg.sender] = true;

        emit TransferApproved(_transferId, msg.sender);
    }

    function executeTransfer(uint256 _transferId) external onlyMultiSigSigners {
       Transfer storage transfer = transfers[_transferId];
        if (transfer.approvals < quorum) revert QuorumHasNotBeenReached(_transferId);
        if (transfer.executed) revert TransferIsAlreadyExecuted(_transferId);

        uint256 balance = address(this).balance;
        if (transfer.amount >= balance) revert InsufficientBalance(balance, transfer.amount);

        (bool success, ) = transfer.to.call{value: transfer.amount}("");
        if (!success) revert TransferFailed(_transferId);

        transfer.executed = true;

        emit TransferExecuted(_transferId);
    }

    /// @notice Default fallback function to receive ether to the contract
    receive() external payable {}

    /// @notice Get the details of a transfer by its ID
    /// @param _transferId The ID of the transfer
    /// @return to The address of the recipient
    /// @return amount The amount of ether to be sent
    /// @return approvals The number of approvals for the transfer
    /// @return executed Whether the transfer has been executed or not
    function getTransfer(uint256 _transferId) external view returns (
        address to,
        uint256 amount,
        uint256 approvals,
        bool executed
        ) {
        Transfer storage transfer = transfers[_transferId];
        return (transfer.to, transfer.amount, transfer.approvals, transfer.executed);
    }

    /// @notice Check if a signer has approved a specific transfer
    /// @param _transferId The ID of the transfer
    /// @param _signer The address of the signer
    /// @return True if the signer has approved the transfer, false otherwise
    function hasSignedTransfer(uint256 _transferId, address _signer) external view returns (bool) {
        Transfer storage transfer = transfers[_transferId];
        return transfer.approved[_signer];
    }

    /// @notice Get the total number of transfers that have been created
    /// @return The total number of transfers
    function getTransfersCount() external view returns (uint256) {
        return transfersCount;
    }

}
