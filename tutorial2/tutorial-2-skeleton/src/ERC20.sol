
// specify solidity version
pragma solidity ^0.8.17;

// import ERC20 interface from file
import "./interfaces/IERC20.sol";


//Our ERC20 contract
// By saying ERC20 is IERC20Metadata, we are saying we will implement all functions defined
// In IERC20Metadata in the IERC20.sol file
// These functions are name, symbol and decimals
// In the interface files, you will notice that IERC20Metadata is specified as
// "interface IERC20Metadata is IERC20"
// This means the metadata interface has the 3 functions it specified above and everything specified in the ERC20 interface
//So our ERC20 contract has all of these functions
contract ERC20 is IERC20Metadata {

    //Set the minter to a public immutable variables
    // Public means everyone can view it (the contract, child contracts, and other contracts and wallets/accounts)
    // immutable means it can be set once and never again
    address public immutable minter;

    //here we specify the required functions from IERC20Metadata
    // We use the keyword override to say we are overriding the blueprint function given in the interface
    // And replacing it with the actual function
    // When you assign a variable to public, it automatically generates a getter funcion of the same name
    // for example, name() is the function that returns the name variable
    string public override name;
    string public override symbol;
    uint8 public constant override decimals = 18;

    // We now override the totalSupply function with another public variable
    // This is the first function from the ERC20 interface
    // Again, this is just a getter function to return the value
    uint256 public override totalSupply;

    // A constructor is run exactly once when the contract is first deployed
    // it is used to initialise variables within the contract
    // We use the name_ and symbol_ variables that are provided as inputs
    // These inputs are temporary in memory and removed after the contract is deployed
    //When the contract is first deployed
    //We then set the minter to msg.sender, the deployers address
    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
        minter = msg.sender;
    }

    //Specify the mappings of an address to their balance
    //This is internal, meaning only the contract and its child contracts can use this mapping
    mapping(address => uint256) internal _balances;
    //Specify the mapping of an address to another mapping of an address to a wallet
    //Address1 gives Address2 an allowance
    mapping(address => mapping(address => uint256)) internal _allowances;

    //Override the balanceOf function from the interface
    //This uses the view keyword, meaning it only views information on the blockchain and changes nothing
    //This means the function costs no gas to run
    //The function is external, meaning the contract cannot call it itself but child contracts, other contracts
    //and other wallets/accounts can
    //Checks the balance of the given address
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    //We do not use override here as it is not specified in the interface file
    //This function mints an amountof coins and adds it to the address
    //We must also increase totalSupply by the same amount
    function mint(address account, uint256 amount) external {
        //Checks the person calling the function is the minter
        //Else it will fail
        require(msg.sender == minter, "only minter can mint");
        _balances[account] += amount;
        totalSupply += amount;
        //emits a Transfer event
        //An emit creates a log of what happened which is added with the transaction to a block
        // The event is the template for the emit, specifying what is added in the log
        //As seen in the interface file, this is the to and from addresses, as well as the amount
        emit Transfer(address(0), account, amount);
    }

    //Function to transfer money from your account to another
    //Notice it uses an internal function called _transfer
    //_transfer allows you to send any amount between any two addresses
    //As we will see later, _transfer is kept internal as it is too powerful to be used by external accounts/contracts
    //And could be exploited (have people send themselves money from other people's accounts)
    function transfer(address to, uint256 value)
        external
        returns (bool success)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    //Function to allow a second account "to", who has an allowance from first account "from"
    // to transfer money from the first account to the second account
    //As long as it is within thee second account's allowance
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool success) {
        require(
            _allowances[from][msg.sender] >= value,
            "insufficient allowance"
        );
        _allowances[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    //As mentioned above, the more general transfer function is kept internal to avoid
    //being exploited
    //First checks if the "from" account has enough funds in their account
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        require(_balances[from] >= value, "insufficient balance");
        _balances[from] -= value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    //Function that gives a second address "spender" permission
    // to withdraw up to "value" amount from the msg.sender
    function approve(address spender, uint256 value)
        external
        returns (bool success)
    {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // View function that simply checks the allowance of "spender" given by "owner"
    function allowance(address owner, address spender)
        external
        view
        returns (uint256 remaining)
    {
        return _allowances[owner][spender];
    }
}