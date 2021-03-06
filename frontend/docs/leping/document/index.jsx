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
const getTextValue = require('./../../../../libs/getTextValue');

const Round = require('./../../../../libs/round_to_2');
const Loading = require('./../../../components/loading/index.jsx');

const DocContext = require('./../../../doc-context');
const LIB_OBJS = require('./../../../../config/constants').LEPING.LIB_OBJS;

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

    }

    render() {
        return <DocumentTemplate docId={this.state.docId}
                                 ref='document'
                                 history={this.props.history}
                                 docTypeId='LEPING'
                                 module={this.props.module}
                                 initData={this.props.initData ? this.props.initData : {}}
                                 reload={true}
                                 libs={LIB_OBJS}
                                 renderer={this.renderer}
                                 createGridRow={this.createGridRow}
                                 gridValidator={this.gridValidateFields}
                                 focusElement={'input-number'}
        />
    }

    /**
     *???????????? ?????????????????? ???????????????????? ??????????????????
     */
    renderer(self) {
        if (!self || !self.docData || !self.docData.kpv || !self.libs['objekt']) {
            return (<div style={styles.doc}>
                <Loading label={'Laadimine...'}/>
            </div>);
        }

        let isEditMode = self.state.edited,
            gridData = self.docData.gridData,
            gridColumns = self.docData.gridConfig,
            mooduData = self.docData.moodu,
            mooduColumns = self.docData.mooduConfig;

        // ?????????????????? ??????????????, ???????????? ????????????????
        const objects = self.libs['objekt'].filter(obj => obj.asutus_id == self.docData.asutusid);

        // ???????? ?????? ??????????, ?????????????? ????
        if (!gridData.length && self.libs['nomenclature'].length) {
            self.libs['nomenclature'].forEach(nom => {
                gridData.push({id: 0, nomid: nom.id, kogus: 0, hind: nom.hind, kood: nom.kood, nimetus: nom.nimetus})
            });
        }

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
                            <InputDate title='Kuup??ev'
                                       name='kpv'
                                       value={self.docData.kpv}
                                       ref='input-kpv'
                                       readOnly={!isEditMode}
                                       onChange={self.handleInputChange}/>
                            <InputDate title='T??htaeg'
                                       name='tahtaeg'
                                       value={self.docData.tahtaeg}
                                       ref="input-tahtaeg"
                                       readOnly={!isEditMode}
                                       onChange={self.handleInputChange}/>

                        </div>

                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <Select title="Korteeriomanik"
                                    name='asutusid'
                                    libs="asutused"
                                    value={self.docData.asutusid}
                                    data={self.libs['asutused']}
                                    defaultValue={String(self.docData.asutus) || ''}
                                    onChange={self.handleInputChange}
                                    collId={'id'}
                                    ref="select-asutus"
                                    readOnly={!isEditMode}/>
                        </div>
                        <div style={styles.docColumn}>
                            {DocContext.module !== 'kasutaja' ? <ButtonEdit
                                ref='btnEdit'
                                value={'Muuda'}
                                onClick={this.btnEditAsutusClick}
                                show={!isEditMode}
                                style={styles.btnEdit}
                                disabled={false}
                            /> : null}

                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.docColumn}>
                            <Select title="Objekt"
                                    name='objektid'
                                    libs="objekt"
                                    value={self.docData.objektid}
                                    data={objects}
                                    defaultValue={String(self.docData.objekt) || ''}
                                    onChange={self.handleInputChange}
                                    collId={'id'}
                                    ref="select-objek"
                                    readOnly={!isEditMode}/>

                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <TextArea title="M??rkused"
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
                    <br/>
                    <div style={styles.docRow}>
                        <label ref="label">
                            {getTextValue('M????du andmed')}
                        </label>
                    </div>

                    <div style={styles.docRow}>
                        <DataGrid source='moodu'
                                  gridData={mooduData}
                                  gridColumns={mooduColumns}
                                  showToolBar={false}
                                  readOnly={true}
                                  style={styles.grid.headerTable}
                                  docTypeId={'andmed'}
                                  ref="moodu-grid"/>
                    </div>
                </div>
            </div>
        );
    }


    /**
     * ?????????????? ???????????????? ???????????? ??????????
     * @returns {XML}
     */
    createGridRow(self) {

        let row = self.gridRowData ? self.gridRowData : {},
            validateMessage = '', // self.state.warning
            buttonOkReadOnly = validateMessage.length > 0 || !self.state.checked,
            modalObjects = ['btnOk', 'btnCancel'];

        if (buttonOkReadOnly) {
            // ???????????? ???????????? ????
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
                    {self.state.gridWarning.length ? (
                        <div style={styles.docRow}>
                            <span>{self.state.gridWarning}</span>
                        </div>
                    ) : null}
                    <div style={styles.docRow}>
                        <div style={styles.contant}>
                            <Select title="Teenus"
                                    name='nomid'
                                    libs="nomenclature"
                                    data={self.libs['nomenclature']}
                                    readOnly={false}
                                    value={row.nomid}
                                    collId='id'
                                    ref='nomid'
                                    style={styles.select}
                                    placeholder='Teenuse kood'
                                    onChange={self.handleGridRowChange}/>
                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.contant}>
                            <InputNumber title='Kogus '
                                         name='kogus'
                                         value={Number(row.kogus ? row.kogus : 0)}
                                         readOnly={false}
                                         disabled={false}
                                         bindData={false}
                                         ref='kogus'
                                         pattern="[0-9]{10}"
                                         onChange={self.handleGridRowInput}/>
                        </div>
                    </div>
                    <div style={styles.docRow}>
                        <div style={styles.contant}>
                            <InputNumber title='Hind '
                                         name='hind'
                                         value={Number(row.hind ? row.hind : 0)}
                                         readOnly={false}
                                         disabled={false}
                                         bindData={false}
                                         ref='hind'
                                         pattern="[0-9]{10}"
                                         onChange={self.handleGridRowInput}/>
                        </div>
                    </div>
                </div>
                <div><span>{validateMessage}</span></div>
            </ModalPage>
        </div>);
    }


    /**
     * ?????????????????? ?????? ???????????? ??????????
     * @returns {string}
     */
    gridValidateFields() {
        let warning = '';
        let doc = this.refs['document'];
        if (doc && doc.gridRowData) {

            // ???????????? ?????????? ???????????????? ?????????? ???? ????????????????????
            if (doc.gridRowData && !doc.gridRowData['nomid']) warning = warning + ' ?????? ????????????????';
            if (!doc.gridRowData['kogus']) warning = warning + ' ????????????????????';
            if (!doc.gridRowData['hind']) warning = warning + ' ??????????';

            // ???????????????????????? ???????????? ?? ??????
            if (doc.gridRowData && doc.gridRowData['nomid']) {
                let teenus = DocContext.libs['nomenclature'].filter(row => row.id == doc.gridRowData['nomid']);
                if (teenus) {
                    doc.gridRowData['kood'] = teenus[0].kood ? teenus[0].kood : null;
                    doc.gridRowData['nimetus'] = teenus[0].nimetus ? teenus[0].nimetus : null;
                }
            }

        }
        return warning;

    }


    // ???????????????????? ?????????????? ???????????? ???? ???????????? ???????????????????????????? ??????????-????????????
    btnEditAsutusClick() {
        let docAsutusId = this.refs['document'].docData.asutusid;

        // ???????????????????? ?????????????? ???? ???????????????? ??????????-????????????
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