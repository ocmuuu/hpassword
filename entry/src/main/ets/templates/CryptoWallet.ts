import { CategoryTemplate } from './TemplateTypes';

export const CryptoWalletTemplate: CategoryTemplate = {
  name: '加密钱包',
  desc: '数字货币地址、助记词或私钥，集中管理区块链资产凭据',
  fields: [
    { key: 'Title', label: '钱包/交易所' },
    { key: 'Address', label: '地址' },
    { key: 'Seed', label: '助记词', protected: true },
    { key: 'PrivateKey', label: '私钥', protected: true },
    { key: 'WalletPassword', label: '钱包密码', protected: true },
    { key: 'Network', label: '网络/链' },
    { key: 'Balance', label: '余额' },
    { key: 'CreationDate', label: '创建日期' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: 'MetaMask',
      Address: '0x1234...abcd',
      Seed: 'apple banana cat ...',
      WalletPassword: 'WalletPassword123!',
      Network: 'Ethereum',
      Balance: '1.5 ETH',
      CreationDate: '2023-05-15',
      Notes: 'ETH 主网'
    }
  ]
}; 