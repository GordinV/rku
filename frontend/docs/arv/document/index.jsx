'use strict';

const PropTypes = require('prop-types');
const React = require('react');

const
    DocumentTemplate = require('../../documentTemplate/index.jsx'),
    InputText = require('../../../components/input-text/input-text.jsx'),
    InputDate = require('../../../components/input-date/input-date.jsx'),
    InputNumber = require('../../../components/input-number/input-number.jsx'),
    Select = require('../../../components/select/select.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    DataGrid = require('../../../components/data-grid/data-grid.jsx'),
    relatedDocuments = require('../../../mixin/relatedDocuments.jsx'),
    ModalPage = require('../../../components/modalpage/modalPage.jsx'),
    ButtonEdit = require('../../../components/button-register/button-register-edit/button-register-edit.jsx'),
    styles = require('./arve.styles');
const Round = require('./../../../../libs/round_to_2');
const Loading = require('./../../../components/loading/index.jsx');
const getTextValue = require('./../../../../libs/getTextValue');

const DocContext = require('./../../../doc-context');
const LIB_OBJS = require('./../../../../config/constants').ARV.LIB_OBJS;
const DocRights = require('./../../../../config/doc_rights');
const checkRights = require('./../../../../libs/checkRights');

class Arve extends React.PureComponent {
    constructor(props) {
        super(props);
        this.state = {
            loadedData: false,
            module: props.module ? props.module : DocContext.module,
            lapsId: null,
            docId: props.docId ? props.docId : Number(props.match.params.docId)
        };

        this.createGridRow = this.createGridRow.bind(this);
        this.recalcDocSumma = this.recalcDocSumma.bind(this);

        this.renderer = this.renderer.bind(this);
        this.gridValidateFields = this.gridValidateFields.bind(this);
        this.btnEditAsutusClick = this.btnEditAsutusClick.bind(this);
        this.pages = [{pageName: 'Arve', docTypeId: 'ARV'}];

    }

    render() {
        return <DocumentTemplate docId={this.state.docId}
                                 ref='document'
                                 history={this.props.history}
                                 docTypeId='ARV'
                                 module={this.state.module}
                                 initData={this.props.initData ? this.props.initData : {}}
                                 reload={true}
                                 libs={LIB_OBJS}
                                 pages={this.pages}
                                 renderer={this.renderer}
                                 createGridRow={this.createGridRow}
                                 gridValidator={this.gridValidateFields}
                                 recalcDoc={this.recalcDocSumma}
                                 focusElement={'input-number'}
        />
    }

    /**
     *Вернет кастомные компоненты документа
     */
    renderer(self) {
        if (!self || !self.docData || !self.docData.kpv) {
            return (<div style={styles.doc}>
                <Loading label={'Laadimine...'}/>
            </div>);
        }

        let isEditMode = self.state.edited,
            gridData = self.docData.gridData,
            gridColumns = self.docData.gridConfig,
            gridArvTasuData = self.docData.queryArvTasu,
            gridTasudColumns = self.docData.gridTasudConfig;


        // формируем зависимости
        if (self.docData.relations) {
            relatedDocuments(self);
        }

        // права на редактирование карточки контрагента
        let docRights = DocRights['ASUTUSED'] ? DocRights['ASUTUSED'] : [];
        let userRoles = DocContext.userData ? DocContext.userData.roles : [];

        return (
            <div>
                <div style={styles.doc}>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <InputText ref="input-number"
                                       title='Number'
                                       name='number'
                                       value={self.docData.number || ''}
                                       readOnly={!isEditMode}
                                       onChange={self.handleInputChange}/>
                            <InputDate title='Kuupäev'
                                       name='kpv'
                                       value={self.docData.kpv}
                                       ref='input-kpv'
                                       readOnly={!isEditMode}
                                       onChange={self.handleInputChange}/>
                            <InputDate title='Tähtaeg'
                                       name='tahtaeg'
                                       value={self.docData.tahtaeg}
                                       ref="input-tahtaeg"
                                       readOnly={!isEditMode}
                                       onChange={self.handleInputChange}/>

                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <Select title="Maksja"
                                    libs="asutused"
                                    name='asutusid'
                                    data={self.libs['asutused']}
                                    value={self.docData.asutusid || 0}
                                    defaultValue={self.docData.asutus}
                                    onChange={self.handleInputChange}
                                    collId={'id'}
                                    readOnly={!isEditMode}/>
                        </div>
                        {checkRights(userRoles, docRights, 'edit') ?
                            <div style={styles.docColumn}>
                                <ButtonEdit
                                    ref='btnEdit'
                                    value={'Muuda'}
                                    onClick={this.btnEditAsutusClick}
                                    show={!isEditMode}
                                    style={styles.btnEdit}
                                    disabled={false}
                                />
                            </div> : null}
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>

                            <InputText title='Lisa'
                                       name='lisa'
                                       value={self.docData.lisa || ''}
                                       ref='input-lisa'
                                       readOnly={!isEditMode}
                                       onChange={self.handleInputChange}/>

                            <InputText title='Viitenumber'
                                       name='viitenr'
                                       value={self.docData.viitenr || ''}
                                       ref='input-viitenumber'
                                       readOnly={true}
                                       disable={true}
                                       onChange={self.handleInputChange}/>
                        </div>
                        <div style={styles.docColumn}>
                            <Select title="Arveldus arve"
                                    name='aa_id'
                                    libs="aa"
                                    value={self.docData.aa}
                                    data={self.libs['aa']}
                                    defaultValue={String(self.docData.aa) || ''}
                                    onChange={self.handleInputChange}
                                    collId={'kood'}
                                    ref="select-aa"
                                    readOnly={!isEditMode}/>

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
                    <div style={styles.docRow}>
                        <InputNumber title="Summa"
                                     name='summa'
                                     ref="input-summa"
                                     value={Number(self.docData.summa) || 0}
                                     disabled={true}
                                     style={styles.summa}
                        />
                        <InputNumber title="Käibemaks"
                                     name='kbm'
                                     ref="input-kbm"
                                     disabled={true}
                                     style={styles.summa}
                                     value={Number(self.docData.kbm) || 0}
                        />
                        <InputNumber title="Jääk"
                                     type='currency'
                                     name='jaak'
                                     ref="input-jaak"
                                     disabled={true}
                                     style={styles.summa}
                                     value={Number(self.docData.jaak) || 0}
                        />
                    </div>
                    {self.state.gridRowEdit ?
                        this.createGridRow(self)
                        : null}
                    <br/>
                    <div style={styles.docRow}>
                        <label ref="label">
                            {getTextValue('Tasud')}
                        </label>
                    </div>
                    <div style={styles.docRow}>
                        <DataGrid source='tasud'
                                  gridData={gridArvTasuData}
                                  gridColumns={gridTasudColumns}
                                  showToolBar={false}
                                  handleGridBtnClick={self.handleGridBtnClick}
                                  docTypeId={'smk'}
                                  readOnly={true}
                                  style={styles.grid.headerTable}
                                  ref="tasud-data-grid"/>
                    </div>
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

        return (<div className='.modalPage'>
            <ModalPage
                modalObjects={modalObjects}
                ref="modalpage-grid-row"
                show={true}
                modalPageBtnClick={self.modalPageClick}
                styles={styles.gridRow}
                modalPageName='Rea lisamine / parandamine'>
                <div ref="grid-row-container">
                    {self.state.gridWarning.length ? (
                        <div style={styles.docRow}>
                            <span>{self.state.gridWarning}</span>
                        </div>
                    ) : null}
                    <div style={styles.docRow}>
                            <Select title="Teenus:"
                                    name='nomid'
                                    libs="nomenclature"
                                    data={self.libs['nomenclature']}
                                    readOnly={false}
                                    value={row.nomid}
                                    collId='id'
                                    ref='nomid'
                                    placeholder='Teenuse kood'
                                    onChange={self.handleGridRowChange}/>
                    </div>
                    <div style={styles.docRow}>
                            <InputNumber title='Kogus:'
                                         name='kogus'
                                         value={Number(row.kogus ? row.kogus : 0)}
                                         readOnly={false}
                                         disabled={false}
                                         bindData={false}
                                         ref='kogus'
                                         pattern="[0-9]{10}"
                                         onChange={self.handleGridRowInput}/>
                    </div>
                    <div style={styles.docRow}>
                            <InputNumber title='Hind:'
                                         name='hind'
                                         value={Number(row.hind ? row.hind : 0)}
                                         readOnly={false}
                                         disabled={false}
                                         bindData={false}
                                         ref='hind'
                                         pattern="[0-9]{10}"
                                         onChange={self.handleGridRowInput}/>
                    </div>
                    <div style={styles.docRow}>
                            <InputNumber title='Kbm-ta:'
                                         name='kbmta'
                                         value={Number(row.summa ? row.summa - row.kbm : 0)}
                                         disabled={true}
                                         bindData={false}
                                         ref='kbmta'
                                         pattern="[0-9]{10}"
                                         onChange={self.handleGridRowChange}/>
                    </div>
                    <div style={styles.docRow}>
                            <InputNumber title='Kbm:'
                                         name='kbm'
                                         value={Number(row.kbm ? row.kbm : 0)}
                                         disabled={true}
                                         bindData={false}
                                         ref='kbm'
                                         pattern="[0-9]{10}"
                                         onBlur={self.handleGridRowInput}/>
                    </div>
                    <div style={styles.docRow}>
                            <InputNumber title='Summa:'
                                         name='Summa'
                                         value={Number(row.summa ? row.summa : 0)}
                                         disabled={true}
                                         bindData={false}
                                         ref='summa'
                                         pattern="[0-9]{10}"
                                         onChange={self.handleGridRowInput}/>
                    </div>
                    <div style={styles.docRow}>
                            <Select title="Tunnus:"
                                    name='tunnus'
                                    data={self.libs['tunnus']}
                                    value={row.tunnus || ''}
                                    ref='tunnus'
                                    collId="kood"
                                    onChange={self.handleGridRowChange}/>
                    </div>
                    <div style={styles.docRow}>
                            <Select title="Projekt:"
                                    name='proj'
                                    data={self.libs['project']}
                                    value={row.proj || ''}
                                    ref='project'
                                    collId="kood"
                                    onChange={self.handleGridRowChange}/>
                    </div>
                    <div style={styles.docRow}>
                        <TextArea title="Märkused:"
                                  name='muud'
                                  ref="gridrow-textarea-muud"
                                  onChange={self.handleGridRowChange}
                                  value={row.muud || ''}/>

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
            if (doc.gridRowData && !doc.gridRowData['nomid']) warning = warning + ' Код операции';
            if (!doc.gridRowData['kogus']) warning = warning + ' Количество';
            if (!doc.gridRowData['summa']) warning = warning + ' Сумма';

            this.recalcRowSumm();
            this.recalcDocSumma('summa');

        }
        return warning;

    }

    /**
     * перерасчет суммы строки и расчет налога
     */
    recalcRowSumm() {
        let doc = this.refs['document'];

        if (!Object.keys(doc.gridRowData).length) {
            return;
        }
        //подставим наименование услогу

        let vat = 0;
        let nomHind = 0;
        if (doc.gridRowData['nomid']) {
            let nomDataName = doc.libs['nomenclature'].find(lib => Number(lib.id) === Number(doc.gridRowData['nomid']));

            if (nomDataName) {
                doc.gridRowData['hind'] = nomDataName.hind && !doc.gridRowData['hind'] ? nomDataName.hind : doc.gridRowData['hind'];
                vat = nomDataName.vat ? Number(nomDataName.vat) / 100 : 0;
                nomHind = nomDataName.hind;
                doc.gridRowData['kood'] = nomDataName.kood ? nomDataName.kood : null;
                doc.gridRowData['nimetus'] = nomDataName.nimetus ? nomDataName.nimetus : null;
                doc.gridRowData['uhik'] = nomDataName.uhik ? nomDataName.uhik : null;
                doc.gridRowData['konto'] = nomDataName.konto ? nomDataName.konto : null;
                doc.gridRowData['tunnus'] = nomDataName.tunnus ? nomDataName.tunnus : null;
                doc.gridRowData['proj'] = nomDataName.proj ? nomDataName.proj : null;
                doc.gridRowData['kood1'] = nomDataName.tegev ? nomDataName.tegev : null;
                doc.gridRowData['kood2'] = nomDataName.allikas ? nomDataName.allikas : null;
                doc.gridRowData['kood5'] = nomDataName.artikkel ? nomDataName.artikkel : null;
            }
        }


        doc.gridRowData['kogus'] = Number(doc.gridRowData.kogus);
        doc.gridRowData['soodustus'] = doc.gridRowData['soodustus'] ? Number(doc.gridRowData.soodustus) : 0;
        doc.gridRowData['hind'] = nomHind && doc.gridRowData['soodustus'] ? Number(nomHind) - doc.gridRowData['soodustus'] : Number(doc.gridRowData.hind);
        doc.gridRowData['kbmta'] = Round(Number(doc.gridRowData['kogus']) * Number(doc.gridRowData['hind']));
        doc.gridRowData['kbm'] = Round(Number(doc.gridRowData['kbmta']) * vat);
        doc.gridRowData['summa'] = Round(Number(doc.gridRowData['kbmta']) + Number(doc.gridRowData['kbm']));

    }

    /**
     * Перерасчет итоговых сумм документа
     */
    recalcDocSumma() {
        let doc = this.refs['document'];

        doc.docData['summa'] = 0;
        doc.docData['kbm'] = 0;
        doc.docData.gridData.forEach(row => {
            doc.docData['summa'] = Number(doc.docData['summa']) + Number(row['summa']);
            doc.docData['kbm'] = Number(doc.docData['kbm']) + Number(row['kbm']);
        });
        doc.docData['summa'] = Round(doc.docData['summa']);
        doc.docData['kbm'] = Round(doc.docData['kbm']);

    }


    // обработчик события клиска на кнопке редактирования контр-агента
    btnEditAsutusClick() {
        let docAsutusId = this.refs['document'].docData.asutusid;

        // осуществит переход на карточку контр-агента
        this.props.history.push(`/${DocContext.module}/asutused/${docAsutusId}`);
    }


}

Arve.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object,
    userData: PropTypes.object,
};

Arve.defaultProps = {
    params: {docId: 0},
    initData: {},
    userData: {}
};


module.exports = (Arve);