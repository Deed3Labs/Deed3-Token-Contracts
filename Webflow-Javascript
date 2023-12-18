<script src="https://cdn.jsdelivr.net/npm/web3@1.3.0/dist/web3.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@walletconnect/web3-provider/dist/umd/index.min.js"></script>
<script>
  let web3;
  const erc20TokenAddress = '0x11FAa53761d30ce3A0D8a62fc05F798657D583Fc';
  const erc20TokenDecimals = 18;
  const minABI = [
    {
      "constant": true,
      "inputs": [{"name": "_owner", "type": "address"}],
      "name": "balanceOf",
      "outputs": [{"name": "balance", "type": "uint256"}],
      "type": "function"
    }
  ];

  const chainData = {
    '0x64': {
      name: 'Gnosis Chain',
      iconUrl: 'gnosis-icon.png'
    },
    '0x1': {
      name: 'Ethereum',
      iconUrl: 'ethereum-icon.png'
    },
    '0x89': {
      name: 'Polygon',
      iconUrl: 'polygon-icon.png'
    },
    '0x5': {
      name: 'Goerli Testnet',
      iconUrl: 'goerli-icon.png'
    }
  };

  function formatNumber(num) {
    if (num >= 1e6) {
      return (num / 1e6).toFixed(2) + 'M';
    } else {
      return num.toLocaleString(undefined, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      });
    }
  }

  function truncateAddress(address) {
    return address.substring(0, 6) + '...' + address.substring(address.length - 4);
  }

  async function getENSName(address) {
    try {
      const ensName = await web3.eth.ens.resolve(address);
      return ensName;
    } catch (error) {
      console.error('Error fetching ENS name:', error);
      return null;
    }
  }

  async function connectWallet() {
    if (typeof window.ethereum !== 'undefined') {
      web3 = new Web3(window.ethereum);
      try {
        const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
        sessionStorage.setItem('connectedAccount', accounts[0]);
        updateUIAfterConnection(accounts[0]);
      } catch (error) {
        console.error('User denied account access:', error);
      }
    } else {
      const provider = new WalletConnectProvider.default({
        rpc: { 100: 'https://rpc.gnosischain.com/' },
        qrcodeModalOptions: { mobileLinks: ["rainbow", "metamask", "argent", "trust", "imtoken", "pillar"] },
      });

      web3 = new Web3(provider);

      try {
        await provider.enable();
        const accounts = await web3.eth.getAccounts();
        sessionStorage.setItem('connectedAccount', accounts[0]);
        updateUIAfterConnection(accounts[0]);
      } catch (error) {
        console.error('Could not get accounts via WalletConnect:', error);
      }
    }
  }

  function updateUIAfterConnection(account) {
    document.getElementById('connectWalletButton').style.display = '';
    document.getElementById('disconnectButton').style.display = 'flex';

    // Update wallet info text and reset its color
    const walletInfoElement = document.getElementById('walletInfo');
    walletInfoElement.innerText = truncateAddress(account);
    walletInfoElement.style.color = '#FFFFFF'; // Reset color to default

    getENSName(account).then(ensName => {
      document.getElementById('UserName').innerText = ensName || 'No ENS Name';
    });
    checkChainId();
    getERC20Balance(account);
}

  async function checkChainId() {
    const chainId = await ethereum.request({ method: 'eth_chainId' });
    const chainInfo = chainData[chainId] || { name: 'Unknown Chain', iconUrl: 'default-icon.png' };
    document.getElementById('chainName').innerText = chainInfo.name;
    document.getElementById('chainIcon').src = chainInfo.iconUrl;
    getERC20Balance(sessionStorage.getItem('connectedAccount'));
  }

  async function switchChain(chainId, rpcUrl, chainName, iconUrl) {
    try {
      await ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: chainId }],
      });
    } catch (switchError) {
      if (switchError.code === 4902) {
        try {
          await ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{ chainId: chainId, rpcUrls: [rpcUrl], chainName: chainName }],
          });
        } catch (addError) {
          console.error('Failed to add the chain:', addError);
        }
      } else {
        console.error('Failed to switch the chain:', switchError);
      }
    }
    document.getElementById('chainName').innerText = chainName;
    document.getElementById('chainIcon').src = iconUrl;
    getERC20Balance(sessionStorage.getItem('connectedAccount'));
  }

  async function getERC20Balance(account) {
    const contract = new web3.eth.Contract(minABI, erc20TokenAddress);
    contract.methods.balanceOf(account).call().then((balance) => {
      const tokenBalance = balance / Math.pow(10, erc20TokenDecimals);
      document.getElementById('tokenBalance').innerText = formatNumber(tokenBalance);
    }).catch((err) => {
      console.error('Error getting token balance:', err);
    });
  }

  function disconnectWallet() {
    // Remove the connected account from session storage
    sessionStorage.removeItem('connectedAccount');

    // Reset UI elements to their default state
    document.getElementById('connectWalletButton').style.display = '';
    document.getElementById('disconnectButton').style.display = 'none';

    // Update wallet info text and change its color to red
    const walletInfoElement = document.getElementById('walletInfo');
    walletInfoElement.innerText = 'Wallet Disconnected';
    walletInfoElement.style.color = '#EE2424';  // Change text color to red

    document.getElementById('tokenBalance').innerText = '0.00';
    document.getElementById('chainName').innerText = 'Connect Wallet';
    document.getElementById('chainIcon').src = 'default-icon.png';

    // Disconnect the web3 provider if it exists and supports disconnection
    if (web3 && web3.currentProvider && typeof web3.currentProvider.disconnect === 'function') {
        web3.currentProvider.disconnect();
    }

    // Set web3 to null to signify that there is no active connection
    web3 = null;
}

  window.addEventListener('DOMContentLoaded', () => {
    const storedAccount = sessionStorage.getItem('connectedAccount');
    if (storedAccount) {
      web3 = new Web3(window.ethereum);
      updateUIAfterConnection(storedAccount);
    }

    document.getElementById('connectWalletButton').addEventListener('click', connectWallet);
    document.getElementById('disconnectButton').addEventListener('click', disconnectWallet);
    document.querySelector('.gnosis-chain-button').addEventListener('click', () => switchChain('0x64', 'https://rpc.gnosischain.com/', 'Gnosis Chain', 'gnosis-icon.png'));
    document.querySelector('.ethereum-button').addEventListener('click', () => switchChain('0x1', 'https://mainnet.infura.io/v3/d97365070ebd437eb4d080bf170ca08f', 'Ethereum', 'ethereum-icon.png'));
    document.querySelector('.polygon-button').addEventListener('click', () => switchChain('0x89', 'https://polygon-rpc.com/', 'Polygon', 'polygon-icon.png'));
    document.querySelector('.goerli-testnet-button').addEventListener('click', () => switchChain('0x5', 'https://goerli.infura.io/v3/d97365070ebd437eb4d080bf170ca08f', 'Goerli Testnet', 'goerli-icon.png'));
  });
</script>
