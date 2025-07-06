// @ts-nocheck
export interface FieldSpec {
  key: string;
  label: string;
  protected?: boolean;
}

export interface CategoryTemplate {
  name: string;
  desc: string;
  fields: FieldSpec[];
  samples: Record<string, string>[];
} 