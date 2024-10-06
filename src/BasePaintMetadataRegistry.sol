// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BasePaintMetadataRegistry is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    struct Metadata {
        string name;
        uint24[] palette;
        uint96 size;
        address proposer;
    }

    mapping(uint256 => Metadata) private registry;

    event MetadataUpdated(uint256 indexed id, string name, uint24[] palette, uint256 size, address proposer);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function setMetadata(uint256 id, string memory name, uint24[] memory palette, uint96 size, address proposer)
        public
        onlyOwner
    {
        registry[id] = Metadata(name, palette, size, proposer);
        emit MetadataUpdated(id, name, palette, size, proposer);
    }

    function batchSetMetadata(
        uint256[] memory ids,
        string[] memory names,
        uint24[][] memory palettes,
        uint96[] memory sizes,
        address[] memory proposers
    ) public onlyOwner {
        require(
            ids.length == names.length && ids.length == palettes.length && ids.length == sizes.length,
            "arrays must have the same length"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            registry[ids[i]] = Metadata(names[i], palettes[i], sizes[i], proposers[i]);
            emit MetadataUpdated(ids[i], names[i], palettes[i], sizes[i], proposers[i]);
        }
    }

    function getMetadata(uint256 id) public view returns (Metadata memory) {
        return registry[id];
    }

    function getName(uint256 id) public view returns (string memory) {
        return registry[id].name;
    }

    function getPalette(uint256 id) public view returns (uint24[] memory) {
        return registry[id].palette;
    }

    function getCanvasSize(uint256 id) public view returns (uint256) {
        return registry[id].size;
    }

    function getProposer(uint256 id) public view returns (address) {
        return registry[id].proposer;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
