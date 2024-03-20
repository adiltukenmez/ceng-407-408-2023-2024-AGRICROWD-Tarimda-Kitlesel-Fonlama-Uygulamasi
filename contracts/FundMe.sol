// SPDX-License-Identifier: MIT
// Pragma
pragma solidity >=0.8.2 <0.9.0;
// Imports
import "./PriceConverter.sol";
//Error Codes
error FundMe_NotOwner();
error FundMe_NotSuccesful();

//Interfaces, Libraries, Contracts

/**
 * @title A contract for crowdfunding
 * @author Adil Tükenmez
 * @notice This contract is to demo a sample funding contract
 * @dev
 */
contract FundMe {
    // Type Declarations
    using PriceConverter for uint256;

    // State Variables
    mapping(address => uint256) public addressToAmountFunded;
    uint256 public constant MINIMUM_USD = 50 * 1e18; //1 x 10*18
    address[] public funders;
    address public immutable i_owner;

    AggregatorV3Interface public priceFeed;

    modifier onlyOwner() {
        // require(msg.sender == i_owner, "Sender is not owner!");
        if (msg.sender != i_owner) {
            revert FundMe_NotOwner();
        } // This is more gas efficient than "require"
        _; //Representing rest of the code
    }

    constructor(address priceFeedAddress) {
        i_owner = msg.sender;
        priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    receive() external payable {
        // If someone send money without calling the fund function this function will be called automaticly
        fund();
    }

    fallback() external payable {
        // If someone send money without calling the fund function && their transaction has some type of data --> this function will be called automaticly
        fund();
    }

    /**
     * @notice This function funds this contract
     * @dev
     */

    function fund() public payable {
        // sending funds to a contract
        require(
            msg.value.getConversionRate(priceFeed) >= MINIMUM_USD,
            "Didn't send enough ETH!"
        ); //1e18 = 1 x 10*18 == 1000000000000000000 Wei == 1 1000000000 Gwei = 1 Ether
        funders.push(msg.sender);
        addressToAmountFunded[msg.sender] = msg.value;
    }

    //Should only work for project owner
    function withdraw() public onlyOwner {
        // reset the investment value of funders
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            addressToAmountFunded[funder] = 0;
        }
        // reset the funders array
        funders = new address[](0);
        // withdrawing the funds

        // transfer
        /*
        payable(msg.sender).transfer(address(this).balance);
        */
        // send
        /*
        bool sendSuccess = payable(msg.sender).send(address(this).balance);
        require(sendSuccess, "Send failed");
        */
        // using call (RECOMMENDED)
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        // require(callSuccess, "Call failed");
        if (callSuccess != true) {
            revert FundMe_NotSuccesful();
        }
    }
    /*
    function transferInvestment() external {
        require(msg.sender == projectOwner, "Only project owner can transfer investment.");
        require(totalInvestment >= investmentThreshold, "Investment threshold has not been reached yet.");
        
        payable(projectOwner).transfer(totalInvestment);
    }

    function refundInvestment() external {
        require(totalInvestment < investmentThreshold, "Investment threshold exceeded, refund cannot be made.");
        require(investments[msg.sender] > 0, "No investment found.");
        
        uint refundAmount = investments[msg.sender];
        investments[msg.sender] = 0;
        payable(msg.sender).transfer(refundAmount);
    }
    */
}
