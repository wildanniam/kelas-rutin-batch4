// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract LiskGarden {
    // ============================================
    // BAGIAN 1: ENUM & STRUCT
    // ============================================
    enum GrowthStage { SEED, SPROUT, GROWING, BLOOMING }

    struct Plant {
        uint256 id;
        address owner;
        GrowthStage stage;
        uint256 plantedDate;
        uint256 lastWatered;
        uint8 waterLevel;     // 0 - 100
        bool exists;
        bool isDead;
    }

    // ============================================
    // BAGIAN 2: STATE VARIABLES
    // ============================================
    mapping(uint256 => Plant) public plants;          // plantId -> Plant
    mapping(address => uint256[]) private userPlants; // pemilik -> daftar plantId
    uint256 public plantCounter;
    address public owner;

    // ============================================
    // BAGIAN 3: CONSTANTS (Game Parameters)
    // ============================================
    uint256 public constant PLANT_PRICE = 0.001 ether;
    uint256 public constant REWARD = 0.003 ether;

    // Interval stage 1 menit
    uint256 public constant STAGE_DURATION = 1 minutes;

    // Water depletion tiap 30 detik, berkurang 2 poin
    uint256 public constant WATER_DEPLETION_INTERVAL = 30 seconds;
    uint256 public constant WATER_DEPLETION_RATE = 2;

    // ============================================
    // BAGIAN 4: EVENTS
    // ============================================
    event PlantSeeded(address indexed owner, uint256 indexed plantId);
    event PlantWatered(uint256 indexed plantId, uint8 newWaterLevel);
    event PlantHarvested(uint256 indexed plantId, address indexed owner, uint256 reward);
    event StageAdvanced(uint256 indexed plantId, GrowthStage newStage);
    event PlantDied(uint256 indexed plantId);

    // ============================================
    // BAGIAN 5: CONSTRUCTOR
    // ============================================
    constructor() {
        owner = msg.sender;
    }

    // ============================================
    // BAGIAN 6: PLANT SEED
    // ============================================
    function plantSeed() external payable returns (uint256) {
        require(msg.value >= PLANT_PRICE, "Saldo kurang: 0.001 ETH");

        plantCounter++;
        uint256 newId = plantCounter;

        plants[newId] = Plant({
            id: newId,
            owner: msg.sender,
            stage: GrowthStage.SEED,
            plantedDate: block.timestamp,
            lastWatered: block.timestamp,
            waterLevel: 100,
            exists: true,
            isDead: false
        });

        userPlants[msg.sender].push(newId);

        emit PlantSeeded(msg.sender, newId);
        return newId;
    }

    // ============================================
    // BAGIAN 7: WATER SYSTEM
    // ============================================
    function calculateWaterLevel(uint256 plantId) public view returns (uint8) {
        Plant memory plant = plants[plantId];
        if (!plant.exists || plant.isDead) return 0;

        uint256 timeSince = block.timestamp - plant.lastWatered;
        uint256 intervals = timeSince / WATER_DEPLETION_INTERVAL;
        uint256 waterLost = intervals * WATER_DEPLETION_RATE;

        if (waterLost >= plant.waterLevel) return 0;
        return uint8(plant.waterLevel - waterLost);
    }

    function updateWaterLevel(uint256 plantId) internal {
        Plant storage plant = plants[plantId];
        if (!plant.exists) return;

        uint8 currentWater = calculateWaterLevel(plantId);
        plant.waterLevel = currentWater;

        if (currentWater == 0 && !plant.isDead) {
            plant.isDead = true;
            emit PlantDied(plantId);
        }
    }

    // Cek saldo contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function waterPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Plant tidak ada");
        require(plant.owner == msg.sender, "Bukan pemilik plant");
        require(!plant.isDead, "Plant sudah mati");

        // (opsional) update dulu biar realistis sebelum refill
        updateWaterLevel(plantId);
        require(!plant.isDead, "Plant mati karena kehabisan air");

        plant.waterLevel = 100;
        plant.lastWatered = block.timestamp;

        emit PlantWatered(plantId, plant.waterLevel);
        updatePlantStage(plantId);
    }

    // ============================================
    // BAGIAN 8: STAGE & HARVEST
    // ============================================
    function updatePlantStage(uint256 plantId) public {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Plant tidak ada");

        updateWaterLevel(plantId);
        if (plant.isDead) return;

        uint256 timeSincePlanted = block.timestamp - plant.plantedDate;
        GrowthStage oldStage = plant.stage;

        if (timeSincePlanted >= 3 * STAGE_DURATION) {
            plant.stage = GrowthStage.BLOOMING;
        } else if (timeSincePlanted >= 2 * STAGE_DURATION) {
            plant.stage = GrowthStage.GROWING;
        } else if (timeSincePlanted >= STAGE_DURATION) {
            plant.stage = GrowthStage.SPROUT;
        } else {
            plant.stage = GrowthStage.SEED;
        }

        if (plant.stage != oldStage) {
            emit StageAdvanced(plantId, plant.stage);
        }
    }

    function harvestPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Plant tidak ada");
        require(plant.owner == msg.sender, "Bukan pemilik plant");
        require(!plant.isDead, "Plant mati, tidak bisa panen");

        updatePlantStage(plantId);
        require(plant.stage == GrowthStage.BLOOMING, "Belum mekar");

        // state change dulu (anti-reentrancy basic)
        plant.exists = false;

        emit PlantHarvested(plantId, msg.sender, REWARD);

        require(address(this).balance >= REWARD, "Saldo kontrak kurang");
        (bool ok, ) = payable(msg.sender).call{value: REWARD}("");
        require(ok, "Transfer reward gagal");
    }

    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    function getPlant(uint256 plantId) external view returns (Plant memory) {
        Plant memory plant = plants[plantId];
        // hitung level air aktual secara on-the-fly
        plant.waterLevel = calculateWaterLevel(plantId);
        return plant;
    }

    function getUserPlants(address user) external view returns (uint256[] memory) {
        return userPlants[user];
        // (kalau mau publik: ubah mapping ke public lalu bikin getter otomatis)
    }

    function withdraw() external {
        require(msg.sender == owner, "Bukan owner");
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, "Withdraw gagal");
    }

    receive() external payable {}
}
