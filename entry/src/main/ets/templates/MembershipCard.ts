import { CategoryTemplate } from './TemplateTypes';

export const MembershipCardTemplate: CategoryTemplate = {
  name: '会员卡',
  desc: '线上或线下会员卡号、条码及等级有效期等信息，方便积分或折扣使用',
  fields: [
    { key: 'Title', label: '商家名称' },
    { key: 'MemberID', label: '会员号' },
    { key: 'Level', label: '会员等级' },
    { key: 'Expiry', label: '到期日期' },
    { key: 'Barcode', label: '条码' }, 
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '星巴克',
      MemberID: 'OK-888888',
      Level: 'Gold',
      Expiry: '2025-12-31',
      Barcode: '1234567890',
      Notes: '享 9 折'
    }
  ]
}; 