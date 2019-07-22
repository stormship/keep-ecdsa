const ECDSAKeepFactory = artifacts.require('./ECDSAKeepFactory.sol');
const ECDSAKeep = artifacts.require('./ECDSAKeep.sol');

const truffleAssert = require('truffle-assertions');

contract('ECDSAKeep', function(accounts) {
  describe("#constructor", async function() {
    it('succeeds', async () => {
        let owner = accounts[0]
        let members = [ owner ];
        let threshold = 1;

        let instance = await ECDSAKeep.new(
            owner,
            members,
            threshold
        );

        expect(instance.address).to.be.not.empty;
    })
  });

  describe('#sign', async function () {
    let instance;

    before(async () => {
        let owner = accounts[0]
        let members = [ owner ];
        let threshold = 1;

        instance = await ECDSAKeep.new(
            owner,
            members,
            threshold
        );
    });

    it('emits event', async () => {
      const digest = '0xbb0b57005f01018b19c278c55273a60118ffdd3e5790ccc8a48cad03907fa521'

      let res = await instance.sign(digest)
      truffleAssert.eventEmitted(res, 'SignatureRequested', (ev) => {
        return ev.digest == digest
      });
    })
  })

  describe("public key", () => {
    let expectedPublicKey = web3.utils.hexToBytes("0x67656e657261746564207075626c6963206b6579")
    let owner = "0xbc4862697a1099074168d54A555c4A60169c18BD";
    let members = ["0x774700a36A96037936B8666dCFdd3Fb6687b08cb"];
    let honestThreshold = 5;

    it("get public key before it is set", async () => {
        let keep = await ECDSAKeep.new(owner, members, honestThreshold);

        let publicKey = await keep.getPublicKey.call().catch((err) => {
            assert.fail(`ecdsa keep creation failed: ${err}`);
        });

        assert.equal(publicKey, undefined, "incorrect public key")
    });

    it("set public key and get it", async () => {
        let keep = await ECDSAKeep.new(owner, members, honestThreshold);

        await keep.setPublicKey(expectedPublicKey).catch((err) => {
            assert.fail(`ecdsa keep creation failed: ${err}`);
        });

        let publicKey = await keep.getPublicKey.call().catch((err) => {
            assert.fail(`cannot get public key: ${err}`);
        });

        assert.equal(
            publicKey,
            web3.utils.bytesToHex(expectedPublicKey),
            "incorrect public key"
        )
    });
  })
});