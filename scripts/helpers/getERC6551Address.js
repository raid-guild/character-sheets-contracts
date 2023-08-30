const path = require('path');
const fs = require('fs');
const [targetEnv, subPath, index] = process.argv.slice(2);

const characterPath = '../../addresses.json';
const addresses = require(path.join(__dirname, characterPath));

const chainId = addresses[targetEnv].chainId;

const addressPath = `../../broadcast/CharacterSheetsImplementation.s.sol/${chainId}/${getLatestTx()}`;

function getLatestTx() {
  let latestTx;
  const files = orderRecentFiles(
    'broadcast/CharacterSheetsImplementation.s.sol/11155111/'
  );
  latestTx = files.length ? files[0] : undefined;
  return latestTx.file;
}

function orderRecentFiles(dir) {
  return fs
    .readdirSync(dir)
    .filter((file) => fs.lstatSync(path.join(dir, file)).isFile())
    .map((file) => ({ file, mtime: fs.lstatSync(path.join(dir, file)).mtime }))
    .sort((a, b) => b.mtime.getTime() - a.mtime.getTime());
}
console.log(addressPath);

const latestTxreceipt = require(path.join(__dirname, addressPath));
let erc6551address = latestTxreceipt.transactions.filter((obj) => {
  for ([key, value] of Object.entries(obj)) {
    if (key == 'additionalContracts') {
      for ([key2, value2] of Object.entries(value)) {
        return value2.address;
      }
    }
  }
})[0].additionalContracts[0].address;

if (erc6551address == undefined) {
  console.error(
    `ERROR: Erc6551 address not found in latest transaction receipt`
  );
  process.exit(1);
}

addresses[targetEnv][subPath][index].Erc6551address = erc6551address;

fs.writeFileSync(
  path.join(__dirname, characterPath),
  JSON.stringify(addresses, null, 2) + '\n'
);
console.log('Erc6551 address updated: ', erc6551address);
