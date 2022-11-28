// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./utils/PaymentSplitterUppgradeable.sol";
import "./utils/Constants.sol";

contract ERC1155NothingUpgradeable is
    Initializable,
    ERC1155BurnableUpgradeable,
    OwnableUpgradeable,
    PaymentSplitterUppgradeable,
    ReentrancyGuardUpgradeable
{
    using AddressUpgradeable for address;
    using Strings for uint256;

    string private _baseURI;
    string public name;
    string public symbol;
    uint256 public redMergeLimit;
    uint256 public redMerged;

    address public wethAddress;
    bool public salesBlocked;

    mapping(uint256 => uint256) private _tokenIdToPrice;

    mapping(address => mapping(uint256 => uint256)) private _mintAllowance;

    modifier mintOnlyAllowed(uint256 amount, uint256 tokenId) {
        checkMintAllowance(tokenId, amount);
        _;
    }
    modifier mintBatchOnlyAllowed(
        uint256[] memory values,
        uint256[] memory ids
    ) {
        require(values.length == ids.length, "Nothing: invalid params length");
        for (uint256 i = 0; i < values.length; i++) {
            checkMintAllowance(ids[i], values[i]);
        }
        _;
    }

    modifier mergeLimit(uint256 redAmount) {
        require(
            redMerged + redAmount <= redMergeLimit,
            "Nothing: merge limit exceeded"
        );
        _;
        redMerged += redAmount;
    }

    event Merge(
        address owner,
        uint256 fromId,
        uint256 toId,
        uint256 fromAmount,
        uint256 toAmount
    );

    event AllowanceChanged(
        address operator,
        address minter,
        uint256 tokenId,
        uint256 allowedAmount
    );

    function initialize(
        string memory baseURI,
        string memory _name,
        string memory _symbol,
        address _wethAddress,
        address[] memory payees,
        uint256[] memory shares_,
        uint256[] memory tokenIds,
        uint256[] memory tokenPrices
    ) public initializer {
        require(_wethAddress.isContract(), "Nothing: weth is non-contract");

        require(tokenIds.length == tokenPrices.length, "Invalid prices params");
        __ERC1155Burnable_init();
        __Ownable_init();
        __PaymentSplitter_init(payees, shares_);
        __ReentrancyGuard_init();

        _baseURI = baseURI;
        name = _name;
        symbol = _symbol;

        wethAddress = _wethAddress;

        salesBlocked = true;
        redMergeLimit = 100;

        if (tokenIds.length > 0) {
            for (uint256 i; i < tokenIds.length; i++) {
                _tokenIdToPrice[tokenIds[i]] = tokenPrices[i];
            }
        }
    }

    function mint(
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) external nonReentrant mintOnlyAllowed(value, id) {
        _decreaseMintAllowance(id, value);
        _mint(to, id, value, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) external nonReentrant mintBatchOnlyAllowed(values, ids) {
        _decreaseBatchMintAllowance(ids, values);
        _mintBatch(to, ids, values, data);
    }

    function mintForWalletsBatch(
        address[] calldata to,
        uint256[] memory ids,
        uint256[] memory values
    ) external nonReentrant mintBatchOnlyAllowed(values, ids) {
        require(
            to.length == ids.length && ids.length == values.length,
            "Nothing: invalid params"
        );
        _decreaseBatchMintAllowance(ids, values);

        for (uint256 i = 0; i < to.length; i++) {
            _mint(to[i], ids[i], values[i], "");
        }
    }

    function buyToken(uint256 id, uint256 value) external {
        require(!salesBlocked, "Nothing: sales locked");
        uint256 _tokenPrice = _tokenIdToPrice[id];
        require(_tokenPrice != 0, "Nothing: not on sale");

        uint256 amountToPay = _tokenPrice * value;
        address sender = _msgSender();
        IERC20Upgradeable _token = IERC20Upgradeable(wethAddress);

        SafeERC20Upgradeable.safeTransferFrom(
            _token,
            sender,
            address(this),
            amountToPay
        );
        _receiveWETH(_token, amountToPay);
        _mint(sender, id, value, "");
    }

    function mergeBlackToRed(address owner) external mergeLimit(1) {
        burn(owner, BLACK_DOT_ID, 10);
        _mint(owner, RED_DOT_ID, 1, "");

        emit Merge(owner, BLACK_DOT_ID, RED_DOT_ID, 10, 1);
    }

    function mergeBlackToRed(address owner, uint256 redAmount)
        external
        mergeLimit(redAmount)
    {
        uint256 burnAmount = 10 * redAmount;

        burn(owner, BLACK_DOT_ID, burnAmount);
        _mint(owner, RED_DOT_ID, redAmount, "");

        emit Merge(owner, BLACK_DOT_ID, RED_DOT_ID, burnAmount, redAmount);
    }

    function mergeRedToYellow(address owner) external {
        burn(owner, RED_DOT_ID, 10);
        _mint(owner, YELLOW_DOT_ID, 1, "");

        emit Merge(owner, RED_DOT_ID, YELLOW_DOT_ID, 10, 1);
    }

    function mergeRedToYellow(address owner, uint256 yellowAmount) external {
        uint256 burnAmount = 10 * yellowAmount;

        burn(owner, RED_DOT_ID, burnAmount);
        _mint(owner, YELLOW_DOT_ID, yellowAmount, "");

        emit Merge(owner, RED_DOT_ID, YELLOW_DOT_ID, burnAmount, yellowAmount);
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked(_baseURI, _id.toString(), ".json"));
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseURI = newBaseURI;
    }

    function setWethAddress(address _newAddress) external onlyOwner {
        require(_newAddress.isContract(), "Nothing: weth is non-contract");

        wethAddress = _newAddress;
    }

    function setAreSalesBlocked(bool _areBlocked) external onlyOwner {
        salesBlocked = _areBlocked;
    }

    function tokenPrice(uint256 tokenId) public view returns (uint256) {
        uint256 price = _tokenIdToPrice[tokenId];
        require(price != 0, "Nothing: token is not on sale");

        return price;
    }

    function setTokenPrice(uint256 tokenId, uint256 amount) external onlyOwner {
        require(amount > 0, "Nothing: invalid price");
        _tokenIdToPrice[tokenId] = amount;
    }

    function setMintAllowance(
        address minter,
        uint256 tokenId,
        uint256 amount
    ) external onlyOwner {
        _mintAllowance[minter][tokenId] = amount;

        emit AllowanceChanged(_msgSender(), minter, tokenId, amount);
    }

    function setRedMergeLimit(uint256 _newLimit) external onlyOwner {
        redMergeLimit = _newLimit;
    }

    function redMergesRemaining() external view returns(uint256) {
        if(redMergeLimit <= redMerged) return 0;
        return redMergeLimit - redMerged;
    }

    function _decreaseMintAllowance(uint256 tokenId, uint256 amount) private {
        address sender = _msgSender();
        uint256 currentAllowance = _mintAllowance[sender][tokenId];
        if (currentAllowance <= amount) {
            _mintAllowance[sender][tokenId] = 0;
        } else {
            _mintAllowance[sender][tokenId] =
                _mintAllowance[sender][tokenId] -
                amount;
        }
    }

    function _decreaseBatchMintAllowance(
        uint256[] memory ids,
        uint256[] memory values
    ) private {
        require(values.length == ids.length, "Nothing: invalid params length");
        for (uint256 i = 0; i < values.length; i++) {
            uint256 tokenId = ids[i];
            uint256 value = values[i];
            _decreaseMintAllowance(tokenId, value);
        }
    }

    function checkMintAllowance(uint256 tokenId, uint256 amount) internal view {
        uint256 allowedAmount = _mintAllowance[_msgSender()][tokenId];
        require(allowedAmount >= amount, "Nothing: insufficient allowance");
    }

    function mintAllowance(address miner, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return _mintAllowance[miner][tokenId];
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        uint256 voucherBurned = 0;
        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (ids[i] == EAR_VOUCHER_ID) {
                    voucherBurned += amounts[i];
                }
            }
        }
        if (voucherBurned > 0) {
            _mint(from, PROOF_NFT_ID, voucherBurned, "");
        }

        super._afterTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
