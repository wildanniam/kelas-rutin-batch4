import { createPublicClient, createWalletClient, http, parseEther, getAddress } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { defineChain } from "viem";

// Define Lisk Sepolia chain
const liskSepolia = defineChain({
    id: 4202,
    name: "Lisk Sepolia",
    nativeCurrency: {
        decimals: 18,
        name: "ETH",
        symbol: "ETH",
    },
    rpcUrls: {
        default: {
            http: ["https://rpc.sepolia-api.lisk.com"],
        },
    },
    blockExplorers: {
        default: {
            name: "Blockscout",
            url: "https://sepolia-blockscout.lisk.com/",
        },
    },
});

async function main() {
    // Replace with your deployed contract address
    const CONTRACT_ADDRESS = getAddress("0x3800D8fa50fD609c989d2126e11411Ad8036Aaf2");

    // Setup Viem clients
    const privateKey = process.env.PRIVATE_KEY?.startsWith('0x')
        ? process.env.PRIVATE_KEY as `0x${string}`
        : `0x${process.env.PRIVATE_KEY}` as `0x${string}`;
    const account = privateKeyToAccount(privateKey);

    const publicClient = createPublicClient({
        chain: liskSepolia,
        transport: http(),
    });

    const walletClient = createWalletClient({
        account,
        chain: liskSepolia,
        transport: http(),
    });

    console.log("LiskGarden contract:", CONTRACT_ADDRESS);
    console.log("");

    // Get plant counter
    const plantCounter = await publicClient.readContract({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: [
            {
                "inputs": [],
                "name": "plantCounter",
                "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [],
                "name": "PLANT_PRICE",
                "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
                "stateMutability": "view",
                "type": "function"
            },
            {
                "inputs": [],
                "name": "plantSeed",
                "outputs": [],
                "stateMutability": "payable",
                "type": "function"
            },
            {
                "inputs": [{ "internalType": "uint256", "name": "plantId", "type": "uint256" }],
                "name": "getPlant",
                "outputs": [
                    { "internalType": "uint256", "name": "id", "type": "uint256" },
                    { "internalType": "address", "name": "owner", "type": "address" },
                    { "internalType": "uint8", "name": "stage", "type": "uint8" },
                    { "internalType": "uint256", "name": "waterLevel", "type": "uint256" },
                    { "internalType": "bool", "name": "isAlive", "type": "bool" }
                ],
                "stateMutability": "view",
                "type": "function"
            }
        ],
        functionName: "plantCounter",
    });
    console.log("Total plants:", plantCounter.toString());

    // Plant a seed (costs 0.001 ETH)
    console.log("\n🌱 Planting a seed...");
    const plantPrice = await publicClient.readContract({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: [
            {
                "inputs": [],
                "name": "PLANT_PRICE",
                "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
                "stateMutability": "view",
                "type": "function"
            }
        ],
        functionName: "PLANT_PRICE",
    });

    const tx = await walletClient.writeContract({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: [
            {
                "inputs": [],
                "name": "plantSeed",
                "outputs": [],
                "stateMutability": "payable",
                "type": "function"
            }
        ],
        functionName: "plantSeed",
        value: plantPrice,
    });
    console.log("✅ Seed planted! Transaction:", tx);

    // Get new plant ID
    const newPlantCounter = await publicClient.readContract({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: [
            {
                "inputs": [],
                "name": "plantCounter",
                "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
                "stateMutability": "view",
                "type": "function"
            }
        ],
        functionName: "plantCounter",
    });
    const plantId = newPlantCounter;
    console.log("Your plant ID:", plantId.toString());

    // Get plant details
    const plant = await publicClient.readContract({
        address: CONTRACT_ADDRESS as `0x${string}`,
        abi: [
            {
                "inputs": [{ "internalType": "uint256", "name": "plantId", "type": "uint256" }],
                "name": "getPlant",
                "outputs": [
                    {
                        "components": [
                            { "internalType": "uint256", "name": "id", "type": "uint256" },
                            { "internalType": "address", "name": "owner", "type": "address" },
                            { "internalType": "enum LiskGarden.GrowthStage", "name": "stage", "type": "uint8" },
                            { "internalType": "uint256", "name": "plantedDate", "type": "uint256" },
                            { "internalType": "uint256", "name": "lastWatered", "type": "uint256" },
                            { "internalType": "uint8", "name": "waterLevel", "type": "uint8" },
                            { "internalType": "bool", "name": "exists", "type": "bool" },
                            { "internalType": "bool", "name": "isDead", "type": "bool" }
                        ],
                        "internalType": "struct LiskGarden.Plant",
                        "name": "",
                        "type": "tuple"
                    }
                ],
                "stateMutability": "view",
                "type": "function"
            }
        ],
        functionName: "getPlant",
        args: [plantId],
    });
    console.log("\n🌿 Plant details:");
    console.log("  - ID:", plant.id.toString());
    console.log("  - Owner:", plant.owner);
    console.log("  - Stage:", plant.stage, "(0=SEED, 1=SPROUT, 2=GROWING, 3=BLOOMING)");
    console.log("  - Planted Date:", new Date(Number(plant.plantedDate) * 1000).toLocaleString());
    console.log("  - Last Watered:", new Date(Number(plant.lastWatered) * 1000).toLocaleString());
    console.log("  - Water Level:", plant.waterLevel.toString());
    console.log("  - Exists:", plant.exists);
    console.log("  - Is Dead:", plant.isDead);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });