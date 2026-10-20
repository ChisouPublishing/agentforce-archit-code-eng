import { api, LightningElement } from 'lwc';

const STEPS = { apply: [1, 'Request'], review: [2, 'Review'], confirm: [3, 'Confirm'], done: [4, 'Done'] };

// Shows where the customer is in the 4 return steps. To fit the chat width (about 380px), it uses a dot progress bar and "Step n of 4"
export default class AfdReturnSteps extends LightningElement {
    @api current = 'apply';
    get number() { return (STEPS[this.current] || STEPS.apply)[0]; }
    get label() { return (STEPS[this.current] || STEPS.apply)[1]; }
}
