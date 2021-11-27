'use strict';

const PropTypes = require('prop-types');
const React = require('react');

const
    DocumentTemplate = require('../../documentTemplate/index.jsx'),
    InputText = require('../../../components/input-text/input-text.jsx'),
    InputDate = require('../../../components/input-date/input-date.jsx'),
    InputNumber = require('../../../components/input-number/input-number.jsx'),
    Select = require('../../../components/select/select.jsx'),
    SelectData = require('../../../components/select-data/select-data.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    DataGrid = require('../../../components/data-grid/data-grid.jsx'),
    relatedDocuments = require('../../../mixin/relatedDocuments.jsx'),
    ModalPage = require('../../../components/modalpage/modalPage.jsx'),
    ButtonEdit = require('../../../components/button-register/button-register-edit/button-register-edit.jsx'),
    styles = require('./styles');
const Round = require('./../../../../libs/round_to_2');
const Loading = require('./../../../components/loading/index.jsx');

const DocContext = require('./../../../doc-context');
const LIB_OBJS = require('./../../../../config/constants').ANDMED.LIB_OBJS;

class Leping extends React.PureComponent {
    constructor(props) {
        super(props);
        this.state = {
            loadedData: false,
            module: props.module ? props.module : DocContext.module,
            docId: props.docId ? props.docId : Number(props.match.params.docId)
        };

        this.createGridRow = this.createGridRow.bind(this);

        this.renderer = this.renderer.bind(this);
        this.gridValidateFields = this.gridValidateFields.bind(this);
        this.btnEditAsutusClick = this.btnEditAsutusClick.bind(this);
        this.pages = [{pageName: 'Andmed', docTypeId: 'ANDMED'}];

    }

    render() {
        return <DocumentTemplate docId={this.state.docId}
                                 ref='document'
                                 history={this.props.history}
                                 docTypeId='ANDMED'
                                 module={this.props.module}
                                 initData={this.props.initData ? this.props.initData : {}}
                                 reload={true}
                                 pages={this.pages}
                                 libs={LIB_OBJS}
                                 renderer={this.renderer}
                                 createGridRow={this.createGridRow}
                                 gridValidator={this.gridValidateFields}
                                 focusElement={'input-kpv'}
        />
    }

    /**
     *Вернет кастомные компоненты документа
     */
    renderer(self) {
        if (!self || !self.docData || !self.docData.kpv || self.libs['leping'].length == 0) {
            return (<div style={styles.doc}>
                <Loading label={'Laadimine...'}/>
            </div>);
        }

        // формируем зависимости
        if (self.docData.relations) {
            relatedDocuments(self);
        }


        let isEditMode = self.state.edited,
            gridData = self.docData.gridData,
            gridColumns = self.docData.gridConfig;

        // фильтруем договоры, только владелец
        const lepingud = self.libs['leping'].filter(leping => leping.user_id == DocContext.userData.userId);

        // если договор только один, то ставим его сразу
        if (lepingud.length == 1 && !self.docData.lepingid) {
            self.docData.lepingid = lepingud[0].id;
        }

        // если указан договор
        if (self.docData.lepingid) {
            lepingud.forEach(row => {
                if (row.id == self.docData.lepingid) {
                    self.docData.asutus = row.asutus;
                    self.docData.objekt = row.nimetus;

                    if (gridData.length == 0) {
                        // пишем услуги
                        // если нет услуг, добавим их
                        row.noms.forEach(nom => {
                            gridData.push({
                                id: 0,
                                nomid: nom.nom_id,
                                kogus: 0,
                                eel_kogus: nom.eel_kogus,
                                hind: nom.hind,
                                kood: nom.kood,
                                nimetus: nom.nimetus
                            })
                        });
                    }

                }
            });

        }

        return (
            <div>
                <div style={styles.doc}>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputDate title='Kuupäev'
                                       name='kpv'
                                       value={self.docData.kpv}
                                       ref='input-kpv'
                                       readOnly={!isEditMode}
                                       onChange={self.handleInputChange}/>
                        </div>
                    </div>
                    {!self.docData.id ?
                        <div style={styles.docRow}>
                            <div style={styles.docColumn}>
                                <Select title="Leping"
                                        name='lepingid'
                                        libs="leping"
                                        value={self.docData.lepingid}
                                        data={lepingud}
                                        defaultValue={String(self.docData.objekt) || ''}
                                        onChange={self.handleInputChange}
                                        collId={'id'}
                                        ref="select-leping"
                                        readOnly={!isEditMode}/>
                            </div>
                        </div> : null}

                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputText ref="input-asutus"
                                       title='Korteriomanik'
                                       name='asutus'
                                       value={self.docData.asutus || ''}
                                       readOnly={true}/>
                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputText ref="input-objekt"
                                       title='Objekt'
                                       name='objekt'
                                       value={self.docData.objekt || ''}
                                       readOnly={true}/>
                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <TextArea title="Märkused"
                                  name='muud'
                                  ref="textarea-muud"
                                  onChange={self.handleInputChange}
                                  value={self.docData.muud || ''}
                                  readOnly={!isEditMode}/>
                    </div>

                    <div style={styles.docRow}>
                        <DataGrid source='details'
                                  gridData={gridData}
                                  gridColumns={gridColumns}
                                  showToolBar={isEditMode}
                                  handleGridRow={this.handleGridRow}
                                  handleGridBtnClick={self.handleGridBtnClick}
                                  readOnly={!isEditMode}
                                  style={styles.grid.headerTable}
                                  ref="data-grid"/>
                    </div>
                    {self.state.gridRowEdit ?
                        this.createGridRow(self)
                        : null}
                </div>
            </div>
        );
    }


    /**
     * Создаст компонет строки грида
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

        const gridRowInputStyle = styles.gridRowInput;

        return (<div className='.modalPage'>
            <ModalPage
                modalObjects={modalObjects}
                ref="modalpage-grid-row"
                show={true}
                modalPageBtnClick={self.modalPageClick}
                modalPageName='Rea lisamine / parandamine'>
                <div ref="grid-row-container">
                    {self.state.gridWarning.length ? (
                        <div style={styles.docRow}>
                            <span>{self.state.gridWarning}</span>
                        </div>
                    ) : null}
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputText title="Teenus"
                                       name='nomid'
                                       readOnly={true}
                                       value={row.nimetus}
                                       style={gridRowInputStyle}
                                       ref='nomid'/>
                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputNumber title='Kogus '
                                         name='kogus'
                                         value={Number(row.kogus ? row.kogus : 0)}
                                         readOnly={false}
                                         disabled={false}
                                         bindData={false}
                                         ref='kogus'
                                         pattern="[0-9]{10}"
                                         style={gridRowInputStyle}
                                         onChange={self.handleGridRowInput}/>
                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputNumber title='Eelmise kogus '
                                         name='eel_kogus'
                                         value={Number(row.eel_kogus ? row.eel_kogus : 0)}
                                         readOnly={true}
                                         style={gridRowInputStyle}
                                         ref='eel_kogus'/>
                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputNumber title='Vahe'
                                         name='vahe'
                                         value={row.kogus ? Number(row.kogus) - Number(row.eel_kogus ? row.eel_kogus : 0) : 0}
                                         readOnly={true}
                                         style={gridRowInputStyle}
                                         ref='vahe'/>
                        </div>
                    </div>
                </div>
                <div><span>{validateMessage}</span></div>
            </ModalPage>
        </div>);
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

//            if (doc.gridRowData && !doc.gridRowData['nomid']) warning = warning + ' Код операции';
            if (!doc.gridRowData['kogus']) warning = warning + ' Kogus';
            if (!doc.gridRowData['nomid']) warning = warning + ' Teenus';
        }
        return warning;

    }


    // обработчик события клиска на кнопке редактирования контр-агента
    btnEditAsutusClick() {
        let docAsutusId = this.refs['document'].docData.asutusid;

        // осуществит переход на карточку контр-агента
        this.props.history.push(`/${this.props.module}/asutused/${docAsutusId}`);
    }

}

Leping.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object,
    userData: PropTypes.object,
};

Leping.defaultProps = {
    params: {docId: 0},
    initData: {},
    userData: {}
};


module.exports = (Leping);