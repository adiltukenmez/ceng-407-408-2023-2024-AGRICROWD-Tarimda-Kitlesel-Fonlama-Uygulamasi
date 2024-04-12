// SPDX-License-Identifier: MIT
// Pragma
pragma solidity >=0.8.2 <0.9.0;
// Imports
import "./PriceConverter.sol";
//Error Codes
error FundMe__NotOwner();
error FundMe__NotSuccesful();

//Interfaces, Libraries, Contracts

/**
 * @title A contract for crowd funding
 * @author Adil Tükenmez
 * @notice This contract is to demo a sample funding contract
 * @dev
 */
contract FundMe {
    // Type Declarations
    using PriceConverter for uint256;

    // State Variables
    mapping(address => uint256) private s_addressToAmountFunded;
    address[] private s_funders;
    address private immutable i_owner;
    uint256 public constant MINIMUM_USD = 50 * 1e18; //1 x 10*18
    AggregatorV3Interface private s_priceFeed;

    modifier onlyOwner() {
        // require(msg.sender == i_owner, "Sender is not owner!");
        if (msg.sender != i_owner) {
            revert FundMe__NotOwner();
        } // This is more gas efficient than "require"
        _; //Representing rest of the code
    }

    constructor(address priceFeedAddress) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
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
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "Didn't send enough ETH!"
        ); //1e18 = 1 x 10*18 == 1000000000000000000 Wei == 1 1000000000 Gwei = 1 Ether
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] = msg.value;
    }

    /**
     * @notice this function lets the owner the withdraw the money from the contract
     */

    //Should only work for project owner
    function withdraw() public onlyOwner {
        // reset the investment value of funders
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        // reset the funders array
        s_funders = new address[](0);
        // withdrawing the funds
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        // require(callSuccess, "Call failed");
        if (callSuccess != true) {
            revert FundMe__NotSuccesful();
        }
    }

    function cheaperWithdraw() public onlyOwner {
        address[] memory funders = s_funders;
        // mappings can't be in memory, sorry!
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        // payable(msg.sender).transfer(address(this).balance);
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(
        address funder
    ) public view returns (uint256) {
        return s_addressToAmountFunded[funder];
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}
