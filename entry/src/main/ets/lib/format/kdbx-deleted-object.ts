import * as XmlUtils from '../utils/xml-utils';
import * as XmlNames from '../defs/xml-names';
import { KdbxUuid } from './kdbx-uuid';
import { KdbxContext } from './kdbx-context';

export class KdbxDeletedObject {
    uuid: KdbxUuid | undefined;
    deletionTime: Date | undefined;

    private readNode(node: any): void {
        switch (node.tagName) {
            case XmlNames.Elem.Uuid:
                this.uuid = XmlUtils.getUuid(node);
                break;
            case XmlNames.Elem.DeletionTime:
                this.deletionTime = XmlUtils.getDate(node);
                break;
        }
    }

    write(parentNode: Node, ctx: KdbxContext): void {
        const node = XmlUtils.addChildNode(parentNode, XmlNames.Elem.DeletedObject);
        XmlUtils.setUuid(XmlUtils.addChildNode(node, XmlNames.Elem.Uuid), this.uuid);
        ctx.setXmlDate(XmlUtils.addChildNode(node, XmlNames.Elem.DeletionTime), this.deletionTime);
    }

    static read(xmlNode: Node): KdbxDeletedObject {
        const deletedObject = new KdbxDeletedObject();
        const nodeAny = xmlNode as any;
        for (let i = 0, cn = nodeAny.childNodes, len = cn.length; i < len; i++) {
            const childNode = (cn[i] as any);
            if (childNode.tagName) {
                deletedObject.readNode(childNode);
            }
        }
        return deletedObject;
    }
}
