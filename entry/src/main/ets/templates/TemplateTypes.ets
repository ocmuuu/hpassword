export interface FieldSpec {
  key: string; // 字段键名，对应Kdbx字段名
  label: string; // UI显示名
  protected?: boolean; // 是否受保护存储
}

export interface CategoryTemplate {
  name: string; // 分类名称（Group名称）
  desc: string; // 分类说明
  fields: FieldSpec[]; // 字段定义列表
  samples: Record<string, string>[]; // 示例条目
} 