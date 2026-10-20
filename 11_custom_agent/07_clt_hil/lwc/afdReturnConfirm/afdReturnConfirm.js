import { api, LightningElement } from 'lwc';

// Return confirmation (editor for c__returnConfirmation). Human-in-the-loop confirmation comes from a checkbox, not a "yes" in the conversation.
export default class AfdReturnConfirm extends LightningElement {
    @api readOnly = false;
    _value;
    @api
    get value() { return this._value; }
    set value(v) {
        this._value = v;
        if (v) {
            this.orderNumber = v.orderNumber || '';
            this.refundAmount = v.refundAmount ?? null;
            this.confirmed = v.confirmed === true;
        }
    }
    orderNumber = '';
    refundAmount = null;
    confirmed = false;

    get hasSummary() { return !!this.orderNumber || this.refundAmount !== null; }
    get amountLabel() { return this.refundAmount === null ? '—' : Number(this.refundAmount).toLocaleString('en-US', { style: 'currency', currency: 'USD' }); }

    handleChange(event) {
        event.stopPropagation();
        this.confirmed = event.target.checked;
        this.dispatchEvent(new CustomEvent('valuechange', {
            // Do not send values that are not on screen (empty values can make the LLM treat the input as incomplete and show the form again)
            detail: { value: this.hasSummary
                ? { orderNumber: this.orderNumber, refundAmount: this.refundAmount, confirmed: this.confirmed }
                : { confirmed: this.confirmed } }
        }));
    }
}
