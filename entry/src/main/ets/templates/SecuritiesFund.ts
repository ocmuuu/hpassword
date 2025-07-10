import { CategoryTemplate } from './TemplateTypes';

export const SecuritiesFundTemplate: CategoryTemplate = {
  name: '证券基金',
  desc: '证券公司交易账号、基金投资平台的交易及资金密码等敏感投资信息',
  fields: [
    { key: 'Title', label: '平台名称' },
    { key: 'AccountNumber', label: '交易账号' },
    { key: 'Password', label: '交易密码', protected: true },
    { key: 'FundPassword', label: '资金密码', protected: true },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '华泰证券',
      AccountNumber: '8A00123456',
      Password: 'Trade#521',
      FundPassword: '080808',
      Notes: '手机 OTP'
    }
  ]
}; 