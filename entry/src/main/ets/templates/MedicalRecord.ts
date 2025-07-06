import { CategoryTemplate } from './TemplateTypes';

export const MedicalRecordTemplate: CategoryTemplate = {
  name: '医疗记录',
  desc: '体检报告、病历或药物使用记录，包含就诊医院与医生信息',
  fields: [
    { key: 'Title', label: '记录标题' },
    { key: 'Hospital', label: '医院' },
    { key: 'Date', label: '日期' },
    { key: 'Doctor', label: '医生' },
    { key: 'Notes', label: '诊断/备注' }
  ],
  samples: [
    {
      Title: '年度体检报告',
      Hospital: '北京协和医院',
      Date: '2024-02-20',
      Doctor: '王主任'
    }
  ]
}; 