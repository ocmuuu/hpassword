import { CategoryTemplate } from './TemplateTypes';

export const UtilityAccountTemplate: CategoryTemplate = {
  name: '公用事业账户',
  desc: '水、电、燃气、宽带等公共事业缴费账号与地区信息',
  fields: [
    { key: 'Title', label: '服务名称' },
    { key: 'AccountNumber', label: '用户号' },
    { key: 'Region', label: '所在地区' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '北京燃气',
      AccountNumber: 'BJ-1234567',
      Region: '北京市'
    }
  ]
}; 