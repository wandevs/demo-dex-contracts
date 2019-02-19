module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  solc: {
    optimizer: {
      enabled: true,
      runs: 200,
    }
  },

  networks: {
    ganache: {
      host: '127.0.0.1',
      port: 8500,
      network_id: '3',
      gas: 4710000,
      gasPrice: 180e9,
      // Mnemonic: 'copy obey episode awake damp vacant protect hold wish primary travel shy'
      from: '0x7c06350cb8640a113a618004a828d3411a4f32d3',
    },
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*', // Match any network id
      gas: 4710000,
      gasPrice: 180e9,
      from: '0xa6d72746a4bb19f46c99bf19b6592828435540b0',
    },
  },
};
