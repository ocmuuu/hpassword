import { CategoryTemplate } from './TemplateTypes';

export const InsurancePolicyTemplate: CategoryTemplate = {
  name: '保险保单',
  desc: '车险、医疗险、人寿险等保险合同的保单号、保障范围与到期日',
  fields: [
    { key: 'Title', label: '保单名称' },
    { key: 'PolicyNumber', label: '保单号' },
    { key: 'Company', label: '保险公司' },
    { key: 'PolicyHolder', label: '投保人' },
    { key: 'Beneficiary', label: '受益人' },
    { key: 'Coverage', label: '保障范围' },
    { key: 'Premium', label: '保费' },
    { key: 'IssueDate', label: '生效日期' },
    { key: 'Expiry', label: '到期日' },
    { key: 'ClaimPhone', label: '理赔电话' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '平安车险',
      PolicyNumber: 'PAIC-2024-000888',
      Company: '中国平安',
      PolicyHolder: '张三',
      Beneficiary: '张三',
      Coverage: '交强险 + 车损险',
      Premium: '3580.00',
      IssueDate: '2024-03-11',
      Expiry: '2025-03-10',
      ClaimPhone: '95511'
    }
  ]
}; 