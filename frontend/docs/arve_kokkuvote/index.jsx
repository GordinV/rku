'use strict';

const React = require('react');
const DocumentRegister = require('./../documents/documents.jsx');
const InputNumber = require('../../components/input-number/input-number.jsx');
const InputText = require('../../components/input-text/input-text.jsx');
const getSum = require('./../../../libs/getSum');

const styles = require('./styles');
const DOC_TYPE_ID = 'ARVE_KOKKUVOTE';
const TOOLBAR_PROPS = {
    add: false,
    edit: false,
    delete: false,
    start: false,
    print: true,
    email: true
};
const DocContext = require('./../../doc-context.js');

/**
 * Класс реализует документ справочника признаков.
 */
class Documents extends React.PureComponent {
    constructor(props) {
        super(props);
        this.renderer = this.renderer.bind(this);
        this.state = {
            arvestatud: 0,
            laekumised: 0,
            read: 0,
            filtri_read: 0
        };

    }

    render() {
        return (
            <div>
                <DocumentRegister initData={this.props.initData}
                                  history={this.props.history ? this.props.history : null}
                                  module={this.props.module}
                                  ref='register'
                                  toolbarProps={TOOLBAR_PROPS}
                                  docTypeId={DOC_TYPE_ID}
                                  style={styles}
                                  render={this.renderer}/>
                <InputText title="Filtri all / read kokku:"
                           name='read_kokku'
                           style={styles.total}
                           ref="input-read"
                           value={String(this.state.filtri_read + '/' + this.state.read) || 0}
                           disabled={true}/>
                <InputNumber title="Arvestatud kokku:"
                             name='arvestatud_kokku'
                             style={styles.total}
                             ref="input-arvestatud"
                             value={Number(this.state.arvestatud) || 0}
                             disabled={true}/>
                <InputNumber title="Laekumised kokku:"
                             name='laekumised_kokku'
                             style={styles.total}
                             ref="input-laekumised"
                             value={Number(this.state.laekumised) || 0}
                             disabled={true}/>
            </div>
        )
    }

    renderer(self) {

        if (!self || !self.gridData || !self.gridData.length) {
            // пока нет данных
            return null;
        }
        let summa = self.gridData ? getSum(self.gridData, 'summa') : 0;
        let tasud = self.gridData ? getSum(self.gridData, 'tasutud') : 0;

        let read = self.gridData && self.gridData.length && self.gridData[0].rows_total ? self.gridData[0].rows_total : 0;
        let filtri_read = self.gridData && self.gridData.length && self.gridData[0].filter_total ? self.gridData[0].filter_total : 0;

        this.setState({
            arvestatud: summa,
            laekumised: tasud,
            read: read,
            filtri_read: filtri_read
        });

    }


}


module.exports = (Documents);


