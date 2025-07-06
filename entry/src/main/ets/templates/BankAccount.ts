import { CategoryTemplate } from './TemplateTypes';

export const BankAccountTemplate: CategoryTemplate = {
  name: '银行账户',
  desc: '储蓄卡、信用卡或对公账户的开户行、卡号、网银凭据等金融信息',
  fields: [
    { key: 'Title', label: '账户名称' },
    { key: 'AccountNumber', label: '账号' },
    { key: 'BankName', label: '开户行' },
    { key: 'UserName', label: '户名' },
    { key: 'Password', label: '网银密码', protected: true },
    { key: 'CVV', label: '信用卡 CVV', protected: true },
    { key: 'Expiry', label: '有效期' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '招商银行信用卡',
      AccountNumber: '622588 1234567890',
      BankName: '招商银行',
      UserName: '张三',
      Password: 'NetBank@123',
      CVV: '123',
      Expiry: '09/28',
      Notes: '短信验证'
    }
  ]
}; 