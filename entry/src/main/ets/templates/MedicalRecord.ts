import { CategoryTemplate } from './TemplateTypes';

export const MedicalRecordTemplate: CategoryTemplate = {
  name: '医疗记录',
  desc: '体检报告、病历或药物使用记录，包含就诊医院与医生信息',
  fields: [
    { key: 'Title', label: '记录标题' },
    { key: 'Hospital', label: '医院' },
    { key: 'Date', label: '日期' },
    { key: 'Doctor', label: '医生' },
    { key: 'PatientID', label: '患者ID' },
    { key: 'Diagnosis', label: '诊断结果' },
    { key: 'Treatment', label: '治疗方案' },
    { key: 'Allergies', label: '过敏史' },
    { key: 'Medication', label: '药物过敏' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Title: '年度体检报告',
      Hospital: '北京协和医院',
      Date: '2024-02-20',
      Doctor: '王主任',
      PatientID: 'P20240220001',
      Diagnosis: '健康状态良好',
      Treatment: '建议定期复查',
      Allergies: '无',
      Medication: '青霉素'
    }
  ]
}; 