'use strict';

const React = require('react');
const Documents = require('./../documents/documents.jsx');
const ToolbarContainer = require('./../../components/toolbar-container/toolbar-container.jsx');
const ReklComponent = require('./../../components/doc_rekl/index.jsx');
const BtnAddMoodu = require('./../../components/button-register/button-register.jsx');
const DocContext = require('./../../doc-context.js');


const styles = require('./styles');
const DOC_TYPE_ID = 'KASUTAJA';
const TOOLBAR_PROPS = require('./../../../config/constants').TEATIS.toolbarProps;


/**
 * Класс реализует документ справочника признаков.
 */
class Register extends React.PureComponent {
    constructor(props) {
        super(props);
        this.btnEditClick = this.btnEditClick.bind(this);
        this.onClickHandler = this.onClickHandler.bind(this);
        this.renderer = this.renderer.bind(this);
        this.data = [];
    }

    render() {
        return (
            <div>
                <Documents initData={this.props.initData}
                           history={this.props.history ? this.props.history : null}
                           module={this.props.module}
                           ref='register'
                           docTypeId={DOC_TYPE_ID}
                           style={styles}
                           btnEditClick={this.btnEditClick}
                           toolbarProps={TOOLBAR_PROPS}
                           render={this.renderer}/>
                <br/>
                <ToolbarContainer position={'left'}
                                  container={{border: '1px solid lightGrey'}}>
                    <ReklComponent history={this.props.history}/>
                </ToolbarContainer>

            </div>);
    }

    renderer(self) {
        if (self.gridData) {
            this.data = self.gridData;
        }
        return (<ToolbarContainer>
            <BtnAddMoodu
                onClick={this.onClickHandler}
                value={'Lisa andmed'}
            />
        </ToolbarContainer>);
    }

    //handler для события клик на кнопках панели
    onClickHandler() {
        //делаем редайрект на создание документа - показания счетчиков
        this.props.history.push(`/kasutaja/ANDMED/0`);
    }


    btnEditClick(row_id) {
        // ищем тип документа
        let gridRowId = this.data.findIndex(row => row.id = row_id);
        if (gridRowId > -1) {
            let docTypeId = this.data[gridRowId].doc_type_id;
            return this.props.history.push({
                pathname: `/${this.props.module}/${docTypeId}/${row_id}`,
                state: {module: this.props.module}
            });
        }
    }
}


module.exports = (Register);


