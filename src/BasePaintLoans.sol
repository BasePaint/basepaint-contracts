// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC721 {
    function ownerOf(uint256 _tokenId) external view returns (address);
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address dst, uint256 wad) external returns (bool);
}

interface IBasePaint {
    function paint(uint256 day, uint256 tokenId, bytes calldata pixels) external;
    function authorWithdraw(uint256[] calldata indexes) external;
}

interface IDelegateRegistry {
    function checkDelegateForERC721(address to, address from, address contract_, uint256 tokenId, bytes32 rights)
        external
        view
        returns (bool);
}

contract BasePaintLoans {
    IWETH internal immutable _weth = IWETH(0x4200000000000000000000000000000000000006);
    IERC721 internal immutable _brush = IERC721(0xD68fe5b53e7E1AbeB5A4d0A6660667791f39263a);
    IBasePaint internal immutable _basepaint = IBasePaint(0xBa5e05cb26b78eDa3A2f8e3b3814726305dcAc83);
    IDelegateRegistry internal immutable _delegate = IDelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);

    uint256 internal _withdrawingDay;

    struct Contribution {
        uint256 totalPoints;
        mapping(address => uint256) points;
        address[] wallets;
    }

    mapping(uint256 => Contribution) public contributions;
    mapping(address => uint256) public ownerFeePartsPerMillion;

    event OwnerFeeUpdated(address owner, uint256 fee);

    function paint(uint256 day, uint256 tokenId, bytes calldata pixels) public {
        // Make sure the user delegated the brush to the artist
        address tokenOwner = _brush.ownerOf(tokenId);
        require(_delegate.checkDelegateForERC721(msg.sender, tokenOwner, address(_brush), tokenId, ""), "Not delegated");

        // Borrow the brush
        _brush.transferFrom(tokenOwner, address(this), tokenId);

        // Paint
        _basepaint.paint(day, tokenId, pixels);

        uint256 points = 1_000_000 * pixels.length / 3;
        uint256 ownerPoints = points * ownerFeePartsPerMillion[tokenOwner] / 1_000_000;
        uint256 artistPoints = points - ownerPoints;

        _addPoionts(day, tokenOwner, ownerPoints);
        _addPoionts(day, msg.sender, artistPoints);

        // Give it back
        _brush.transferFrom(address(this), tokenOwner, tokenId);
    }

    function _addPoionts(uint256 day, address author, uint256 points) internal {
        if (points == 0) {
            return;
        }

        Contribution storage contribution = contributions[day];
        if (contribution.points[author] == 0) {
            contribution.wallets.push(author);
        }
        contribution.points[author] += points;
        contribution.totalPoints += points;
    }

    function setOwnerFee(uint256 newFee) public {
        require(newFee <= 1_000_000, "Invalid fee");

        ownerFeePartsPerMillion[msg.sender] = newFee;
        emit OwnerFeeUpdated(msg.sender, newFee);
    }

    function withdraw(uint256 day) public {
        require(_withdrawingDay == 0, "Already withdrawing");

        _withdrawingDay = day;

        uint256[] memory indexes = new uint256[](1);
        indexes[0] = day;

        _basepaint.authorWithdraw(indexes);

        _withdrawingDay = 0;
    }

    receive() external payable {
        require(_withdrawingDay > 0, "Invalid day");

        Contribution storage contribution = contributions[_withdrawingDay];
        for (uint256 i = 0; i < contribution.wallets.length; i++) {
            address wallet = contribution.wallets[i];
            uint256 amount = msg.value * contribution.points[wallet] / contribution.totalPoints;

            (bool success,) = wallet.call{value: amount, gas: 40_000}("");
            if (!success) {
                _weth.deposit{value: amount}();
                require(_weth.transfer(wallet, amount), "WETH transfer failed");
            }
        }

        delete contributions[_withdrawingDay];
    }
}
