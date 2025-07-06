import { CategoryTemplate } from './TemplateTypes';

export const KeyCertificateTemplate: CategoryTemplate = {
  name: '密钥证书',
  desc: 'SSH/TLS/PGP 等加密证书及私钥、口令，方便安全运维',
  fields: [
    { key: 'Title', label: '证书名称' },
    { key: 'Type', label: '类型' },
    { key: 'PrivateKey', label: '私钥', protected: true },
    { key: 'PublicKey', label: '公钥' },
    { key: 'Passphrase', label: '口令', protected: true },
    { key: 'Expiry', label: '到期日' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: 'Github SSH',
      Type: 'ED25519',
      PrivateKey: '-----BEGIN OPENSSH PRIVATE KEY-----...',
      PublicKey: 'ssh-ed25519 AAAA...',
      Notes: '无口令'
    }
  ]
}; 