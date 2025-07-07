import { CategoryTemplate } from './TemplateTypes';

export const FamilyTemplate: CategoryTemplate = {
  name: '家庭成员信息',
  desc: '家人证件号、医保卡等重要身份资料，便于统一管理',
  fields: [
    { key: 'Name', label: '姓名' },
    { key: 'Relation', label: '关系' },
    { key: 'ID', label: '身份证号' },
    { key: 'Passport', label: '护照号' },
    { key: 'MedicalID', label: '医保卡号' },
    { key: 'Phone', label: '电话' },
    { key: 'Birthday', label: '生日' },
    { key: 'Address', label: '地址' },
    { key: 'Notes', label: '备注' }
  ],
  samples: [
    {
      Name: '李四',
      Relation: '父亲',
      ID: '110101196012121234',
      Passport: 'E12345678',
      MedicalID: 'BJ-MED-0001',
      Phone: '13900001234',
      Birthday: '1960-12-12',
      Address: '北京市东城区示例街 10 号'
    }
  ]
}; 