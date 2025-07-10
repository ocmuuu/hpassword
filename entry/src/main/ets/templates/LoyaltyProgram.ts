import { CategoryTemplate } from './TemplateTypes';

export const LoyaltyProgramTemplate: CategoryTemplate = {
  name: '积分计划',
  desc: '航空、酒店、商场等积分/里程计划账号及当前积分余额',
  fields: [
    { key: 'Title', label: '计划名称' },
    { key: 'MemberID', label: '会员号' },
    { key: 'Password', label: '登录密码', protected: true },
    { key: 'Points', label: '当前积分' },
    { key: 'Expiry', label: '积分有效期' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '万豪礼赏',
      MemberID: '88888888',
      Password: 'Marriott2024',
      Points: '12000',
      Expiry: '2025-12-31' 
    }
  ]
}; 