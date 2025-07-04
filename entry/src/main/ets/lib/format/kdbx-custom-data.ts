import * as XmlUtils from '../utils/xml-utils';
import * as XmlNames from '../defs/xml-names';
import { KdbxContext } from './kdbx-context';

export type KdbxCustomDataItem = { value: string | undefined; lastModified?: Date | undefined };

export type KdbxCustomDataMap = Map<string, KdbxCustomDataItem>;

export class KdbxCustomData {
    static read(xmlNode: Node): KdbxCustomDataMap {
        const customData = new Map<string, KdbxCustomDataItem>();
        const nodeAny = xmlNode as any;
        for (let i = 0, cn = nodeAny.childNodes, len = cn.length; i < len; i++) {
            const childNode = (cn[i] as any);
            if (childNode.tagName === XmlNames.Elem.StringDictExItem) {
                KdbxCustomData.readItem(childNode, customData);
            }
        }
        return customData;
    }

    static write(
        parentNode: Node,
        ctx: KdbxContext,
        customData: KdbxCustomDataMap | undefined
    ): void {
        if (!customData) {
            return;
        }
        const node = XmlUtils.addChildNode(parentNode, XmlNames.Elem.CustomData);
        for (const [key, item] of customData) {
            if (item?.value) {
                const itemNode = XmlUtils.addChildNode(node, XmlNames.Elem.StringDictExItem);
                XmlUtils.setText(XmlUtils.addChildNode(itemNode, XmlNames.Elem.Key), key);
                XmlUtils.setText(XmlUtils.addChildNode(itemNode, XmlNames.Elem.Value), item.value);
                if (item.lastModified && ctx.kdbx.versionIsAtLeast(4, 1)) {
                    XmlUtils.setDate(
                        XmlUtils.addChildNode(itemNode, XmlNames.Elem.LastModTime),
                        item.lastModified
                    );
                }
            }
        }
    }

    private static readItem(node: any, customData: KdbxCustomDataMap): void {
        let key = '';
        let value = '';
        const nodeAny = node as any;
        for (let i = 0, cn = nodeAny.childNodes, len = cn.length; i < len; i++) {
            const childNode = (cn[i] as any);
            switch (childNode.tagName) {
                case XmlNames.Elem.Key:
                    key = XmlUtils.getText(childNode) || '';
                    break;
                case XmlNames.Elem.Value:
                    value = XmlUtils.getText(childNode) || '';
                    break;
            }
        }
        if (key) {
            customData.set(key, { value });
        }
    }
}
