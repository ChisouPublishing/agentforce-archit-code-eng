import { api, LightningElement } from 'lwc';

// List of order cards (collection renderer for c__orderCard). value is an array of cards.
export default class AfdOrderCards extends LightningElement {
    @api value;

    get cards() {
        return (this.value || []).map((o) => ({
            ...o,
            icon: o.returnable ? 'standard:return_order' : 'standard:orders',
            badgeIcon: o.returnable ? 'utility:success' : 'utility:ban',
            badgeClass: o.returnable ? 'slds-theme_success' : ''
        }));
    }
    get count() { return (this.value || []).length; }
    get returnableCount() { return (this.value || []).filter((o) => o.returnable).length; }

    // Global copy: order number, order date, and status, one line each (tab-separated, pastes into a spreadsheet)
    @api
    getFormattedValue() {
        return (this.value || []).map((o) => `${o.orderNumber}\t${o.orderDate}\t${o.totalAmount}\t${o.note}`).join('\n');
    }
}
