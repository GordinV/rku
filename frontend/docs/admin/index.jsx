'use strict';

const React = require('react');
const Documents = require('./../documents/documents.jsx');
const styles = require('./styles');
const DOC_TYPE_ID = 'ADMIN';
const TOOLBAR_PROPS = require('./../../../config/constants').TEATIS.toolbarProps;


/**
 * Класс реализует документ справочника признаков.
 */
class Register extends React.PureComponent {
    constructor(props) {
        super(props);
        this.btnEditClick = this.btnEditClick.bind(this);
        this.renderer = this.renderer.bind(this);
        this.data = [];
    }

    render() {
        return <Documents initData={this.props.initData}
                          history={this.props.history ? this.props.history : null}
                          module={this.props.module}
                          ref='register'
                          docTypeId={DOC_TYPE_ID}
                          style={styles}
                          btnEditClick={this.btnEditClick}
                          toolbarProps={TOOLBAR_PROPS}
                          render={this.renderer}/>;
    }

    renderer(self) {
        if (self.gridData) {
            this.data = self.gridData;
        }

        return null;
    }

    btnEditClick(row_id) {
        // ищем тип документа
        let gridRowId = this.data.findIndex(row => row.id = row_id);
        if (gridRowId > -1) {
            let docTypeId = this.data[gridRowId].doc_type_id;
            return this.props.history.push({
                pathname: `/admin/${docTypeId}/${row_id}`,
                state: {module: this.props.module}
            });
        }
    }
}


module.exports = (Register);


