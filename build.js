const fs = require("fs");
const { execSync } = require("child_process");
const args = process.argv.slice(2);

//<major>.<minor>.<patch>+<build_number>
const versionNameResolve = {
    '--major': 0,
    '--minor': 1,
    '--patch': 2,
    '--build': 3
}

console.log("Received arguments:", args);

const pubspecPath = "pubspec.yaml";

// Read pubspec.yaml
let pubspecContent = fs.readFileSync(pubspecPath, "utf8");

// Extract the current version
const versionMatch = pubspecContent.match(/version:\s*([\d.]+)\+(\d+)/);

if (!versionMatch) {
    console.error("Error: Could not find version in pubspec.yaml");
    process.exit(1);
}

const newVersion = buildGenerator(versionMatch, args);

// Replace the version in pubspec.yaml
pubspecContent = pubspecContent.replace(versionMatch[0], newVersion);
fs.writeFileSync(pubspecPath, pubspecContent, "utf8");

console.log(`Updated version to: ${newVersion}`);


try {
    execSync("flutter build appbundle", { stdio: "inherit" });
} catch (error) {
    console.error("Build failed:", error.message);
    process.exit(1);
}




function buildGenerator(previousVersion = [], buildType = []) {
    const result = "version: ";
    const [currentVersion, MajorMinorPatch, currentBuild] = previousVersion;
    let [major, minor, patch, buildNumber] = splitAndConvert(MajorMinorPatch);
    buildNumber = Number(currentBuild) || 0;
    switch (versionNameResolve[buildType[0].trim()]) {
        case 0:
            ++major;
            break;
        case 1:
            ++minor;
            break;
        case 2:
            ++patch;
            break;
        case 3:
            ++buildNumber;
            break;
        default:
            console.log("Please check version in pubspec.yaml")
            break;
    }
    const combinedMMP = [major, minor, patch].join(".");
    return `${result}${combinedMMP}+${buildNumber}`
}

function splitAndConvert(MajorMinorPatch) {
    return MajorMinorPatch?.split?.(".")?.map?.((value) => Number(value) || 0) || [1, 0, 0];
}