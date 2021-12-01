'use strict';
const React = require('react');
const PropTypes = require('prop-types');

const DocContext = require('../../../doc-context');

const
    DocumentTemplate = require('./../../documentTemplate/index.jsx'),
    InputText = require('../../../components/input-text/input-text.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    ModalPage = require('../../../components/modalpage/modalPage.jsx'),
    styles = require('./asutused.styles');
const DataGrid = require('../../../components/data-grid/data-grid.jsx');
const Loading = require('./../../../components/loading/index.jsx');
const getTextValue = require('./../../../../libs/getTextValue');


class Asutused extends React.PureComponent {
    constructor(props) {
        super(props);
        this.state = {
            docId: props.docId ? props.docId : Number(props.match.params.docId),
            loadedData: false
        };
        this.createGridRow = this.createGridRow.bind(this);

        this.renderer = this.renderer.bind(this);
        this.handleGridRow = this.handleGridRow.bind(this);
        this.gridValidateFields = this.gridValidateFields.bind(this);
    }

    render() {
        return <DocumentTemplate docId={this.state.docId}
                                 ref='document'
                                 history={this.props.history}
                                 module={DocContext.module}
                                 docTypeId='ASUTUSED'
                                 initData={this.props.initData}
                                 renderer={this.renderer}
                                 createGridRow={this.createGridRow}
                                 gridValidator={this.gridValidateFields}
                                 focusElement={'input-regkood'}

        />
    }

    renderer(self) {
        if (!self.docData || !self.docData.nimetus) {

            return (<div style={styles.doc}>
                <Loading label={'Laadimine...'}/>
            </div>);
        }


        let isEditeMode = self.state.edited;

        const gridUserData = self.docData.asutus_user,
            gridUserColumns = self.docData.gridAsutusUserConfig,
            gridAaData = self.docData.gridData,
            gridAaColumns = self.docData.gridConfig,
            gridObjectsData = self.docData.objects,
            gridObjectsColumns = self.docData.gridObjectsConfig;

        return (
            <div style={styles.doc}>
                <div style={styles.docRow}>
                    <div style={styles.docColumn}>
                        <InputText title="Reg.kood/ Isikukood"
                                   name='regkood'
                                   ref="input-regkood"
                                   readOnly={!isEditeMode}
                                   value={self.docData.regkood || ''}
                                   onChange={self.handleInputChange}/>
                        <InputText title="Nimetus"
                                   name='nimetus'
                                   ref="input-nimetus"
                                   readOnly={!isEditeMode}
                                   value={self.docData.nimetus || ''}
                                   onChange={self.handleInputChange}/>
                        <InputText title="Om.vorm"
                                   name='omvorm'
                                   ref="input-omvorm"
                                   readOnly={!isEditeMode}
                                   value={self.docData.omvorm || ''}
                                   onChange={self.handleInputChange}/>
                        <InputText title="Telefon"
                                   name='tel'
                                   ref="input-tel"
                                   value={self.docData.tel || ''}
                                   readOnly={!isEditeMode}
                                   onChange={self.handleInputChange}/>
                        <InputText title="Email"
                                   name='email'
                                   ref="input-email"
                                   value={self.docData.email || ''}
                                   readOnly={!isEditeMode}
                                   onChange={self.handleInputChange}/>
                        <label ref="label">
                            {getTextValue('Arvelduste arved')}
                        </label>
                        <div style={styles.docRow}>
                            <DataGrid source='asutus_aa'
                                      gridData={gridAaData}
                                      gridColumns={gridAaColumns}
                                      showToolBar={isEditeMode}
                                      readOnly={!isEditeMode}
                                      style={styles.grid.headerTable}
                                      handleGridRow={self.handleGridRow}
                                      handleGridBtnClick={self.handleGridBtnClick}
                                      ref="asutus_aa-data-grid"/>
                        </div>
                        {self.state.gridRowEdit ?
                            this.createGridRow(self)
                            : null}


                    </div>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Aadress"
                              name='aadress'
                              ref="textarea-aadress"
                              onChange={self.handleInputChange}
                              value={self.docData.aadress || ''}
                              readOnly={!isEditeMode}/>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Kontakt"
                              name='kontakt'
                              ref="textarea-kontakt"
                              onChange={self.handleInputChange}
                              value={self.docData.kontakt || ''}
                              readOnly={!isEditeMode}/>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Muud"
                              name='muud'
                              ref="textarea-muud"
                              onChange={self.handleInputChange}
                              value={self.docData.muud || ''}
                              readOnly={!isEditeMode}/>
                </div>
                <div style={styles.docRow}>
                    <TextArea title="Märkused"
                              name='mark'
                              ref="textarea-mark"
                              onChange={self.handleInputChange}
                              value={self.docData.mark || ''}
                              readOnly={!isEditeMode}/>
                </div>
                <div style={styles.docRow}>
                    <label ref="label">
                        {getTextValue('Kasutaja objektid')}
                    </label>
                </div>
                <div style={styles.docRow}>

                    <DataGrid source='objects'
                              gridData={gridObjectsData}
                              gridColumns={gridObjectsColumns}
                              showToolBar={false}
                              readOnly={true}
                              style={styles.grid.headerTable}
                              docTypeId={'object'}
                              ref="objects-data-grid"/>
                </div>
                <div style={styles.docRow}>
                    <label ref="label">
                        {getTextValue('Kasutaja andmed')}
                    </label>
                </div>
                <div style={styles.docRow}>

                    <DataGrid source='userid'
                              gridData={gridUserData}
                              gridColumns={gridUserColumns}
                              showToolBar={false}
                              readOnly={true}
                              style={styles.grid.headerTable}
                              docTypeId={'userid'}
                              ref="userid-data-grid"/>
                </div>

            </div>


        );
    }

    /**
     * формирует объекты модального окна редактирования строки грида
     * @returns {XML}
     */
    createGridRow(self) {
        let row = self.gridRowData ? self.gridRowData : {},
            validateMessage = '', // self.state.warning
            buttonOkReadOnly = validateMessage.length > 0 || !self.state.checked,
            modalObjects = ['btnOk', 'btnCancel'];

        if (buttonOkReadOnly) {
            // уберем кнопку Ок
            modalObjects.splice(0, 1);
        }

        if (!row) return <div/>;

        return (<div className='.modalPage'>
                <ModalPage
                    modalObjects={modalObjects}
                    ref="modalpage-grid-row"
                    show={true}
                    modalPageBtnClick={self.modalPageClick}
                    modalPageName='Rea lisamine / parandamine'>
                    <div ref="grid-row-container">
                        <div style={styles.docRow}>
                            <InputText title='Arveldus arve: '
                                       name='aa'
                                       value={row.aa || ''}
                                       bindData={false}
                                       ref='aa'
                                       onChange={self.handleGridRowInput}/>
                        </div>
                    </div>
                    <div><span>{validateMessage}</span></div>
                </ModalPage>
            </
                div>
        )
            ;
    }

    /**
     * валидатор для строки грида
     * @returns {string}
     */
    gridValidateFields() {
        let warning = '';
        let doc = this.refs['document'];
        if (doc && doc.gridRowData) {

            // только после проверки формы на валидность
            if (doc.gridRowData && !doc.gridRowData['aa']) warning = warning + ' Расчетный счет';

        }
        return warning;

    }

    /**
     *  управление модальным окном
     * @param gridEvent
     */
    handleGridRow(gridEvent) {
        this.setState({gridRowEdit: true, gridRowEvent: gridEvent});
    }


}

Asutused.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object,
    userData: PropTypes.object
};

Asutused.defaultProps = {
    initData: {},
    userData: {}
};

module.exports = (Asutused);
