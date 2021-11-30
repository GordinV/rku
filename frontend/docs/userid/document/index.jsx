'use strict';
const React = require('react');
const PropTypes = require('prop-types');

const DocumentTemplate = require('./../../documentTemplate/index.jsx'),
    InputText = require('../../../components/input-text/input-text.jsx'),
    TextArea = require('../../../components/text-area/text-area.jsx'),
    CheckBox = require('../../../components/input-checkbox/input-checkbox.jsx'),
    styles = require('./styles');
const DataGrid = require('../../../components/data-grid/data-grid.jsx');
const getTextValue = require('./../../../../libs/getTextValue');
const Loading = require('./../../../components/loading/index.jsx');


const DocContext = require('./../../../doc-context.js');
const DocRights = require('./../../../../config/doc_rights');
const checkRights = require('./../../../../libs/checkRights');


/**
 * Класс реализует документ справочника признаков.
 */
class User extends React.PureComponent {
    constructor(props) {
        super(props);

        this.state = {
            docId: props.docId ? props.docId : Number(props.match.params.docId),
            loadedData: false
        };
        this.renderer = this.renderer.bind(this);
    }

    render() {
        return (

            <DocumentTemplate docId={this.state.docId}
                              ref='document'
                              docTypeId='USERID'
                              module={this.props.module}
                              initData={this.props.initData}
                              renderer={this.renderer}
                              userData={this.props.userData}
                              history={this.props.history}
                              focusElement={'input-kasutaja'}
            />
        )
    }

    /**
     * Метод вернет кастомный компонент
     * @param self
     * @returns {*}
     */
    renderer(self) {
        if (!self || !self.docData || !self.docData.kasutaja) {
            return (<div style={styles.doc}>
                <Loading label={'Laadimine...'}/>
            </div>);
        }
        // вычислим права на редактирование
        let userRoles = DocContext.userData ? DocContext.userData.roles : [];
        let docRightsUserid = DocRights['USERID'] ? DocRights['USERID'] : [];
        let kas_admin = checkRights(userRoles, docRightsUserid, 'edit');

        return (
            <div style={styles.doc}>
                <div style={styles.docRow}>
                    <div style={styles.docColumn}>
                        <InputText title="Kasutaja tunnus:"
                                   name='kasutaja'
                                   ref="input-kasutaja"
                                   readOnly={!kas_admin}
                                   value={self.docData.kasutaja || ''}
                                   onChange={self.handleInputChange}/>
                        <InputText title="Nimi:"
                                   name='ametnik'
                                   ref="input-ametnik"
                                   readOnly={!self.state.edited}
                                   value={self.docData.ametnik || ''}
                                   onChange={self.handleInputChange}/>
                        {Boolean(self.docData.is_raama) || Boolean(self.docData.is_juht) || Boolean(self.docData.is_admin) ?
                            <div>
                                <InputText title="Email:"
                                           name='email'
                                           ref="input-email"
                                           readOnly={!self.state.edited}
                                           value={self.docData.email || ''}
                                           onChange={self.handleInputChange}/>
                                < InputText title="Smtp:"
                                            name='smtp'
                                            ref="input-smtp"
                                            readOnly={!self.state.edited}
                                            value={self.docData.smtp || ''}
                                            onChange={self.handleInputChange}/>
                                <InputText title="Port:"
                                           name='port'
                                           ref="input-port"
                                           readOnly={!self.state.edited}
                                           value={self.docData.port || ''}
                                           onChange={self.handleInputChange}/>
                                <InputText title="Email kasutaja:"
                                           name='user'
                                           ref="input-user"
                                           readOnly={!self.state.edited}
                                           value={self.docData.user || ''}
                                           onChange={self.handleInputChange}/>
                                <InputText title="Email parool:"
                                           name='pass'
                                           ref="input-pass"
                                           readOnly={!self.state.edited}
                                           value={self.docData.pass || ''}
                                           onChange={self.handleInputChange}/>
                            </div>
                            : null}
                        <CheckBox title="Kas kasutaja"
                                  name='is_kasutaja'
                                  value={Boolean(self.docData.is_kasutaja)}
                                  ref={'checkbox_is_kasutaja'}
                                  onChange={self.handleInputChange}
                                  readOnly={!kas_admin}
                        />
                        <CheckBox title="Kas juhataja"
                                  name='is_juht'
                                  value={Boolean(self.docData.is_juht)}
                                  ref={'checkbox_is_juht'}
                                  onChange={self.handleInputChange}
                                  readOnly={!kas_admin}
                        />
                        <CheckBox title="Kas administraator"
                                  name='is_admin'
                                  value={Boolean(self.docData.is_admin)}
                                  ref={'checkbox_is_admin'}
                                  onChange={self.handleInputChange}
                                  readOnly={!kas_admin}
                        />
                        <CheckBox title="Kas raamatupidaja"
                                  name='is_raama'
                                  value={Boolean(self.docData.is_raama)}
                                  ref={'checkbox_is_raama'}
                                  onChange={self.handleInputChange}
                                  readOnly={!kas_admin}
                        />
                    </div>
                </div>

                <div style={styles.docRow}>
                    <TextArea title="Muud"
                              name='muud'
                              ref="textarea-muud"
                              onChange={self.handleInputChange}
                              value={self.docData.muud || ''}
                              readOnly={!self.state.edited}/>
                </div>
                <br/>
                {self.docData.gridData.length > 0 ?
                    <div>
                        <div style={styles.docRow}>
                            <label ref="label">
                                {getTextValue('Klient')}
                            </label>
                        </div>
                        < div style={styles.docRow}>
                            < DataGrid source='details'
                                       gridData={self.docData.gridData}
                                       gridColumns={self.docData.gridConfig}
                                       showToolBar={false}
                                       handleGridBtnClick={self.handleGridBtnClick}
                                       docTypeId={'asutus'}
                                       readOnly={true}
                                       style={styles.grid.headerTable}
                                       ref="asutus-data-grid"/>
                        </div>
                    </div>
                    : null}


            </div>
        );
    }

}

User.propTypes = {
    docId: PropTypes.number,
    initData: PropTypes.object
};

User.defaultProps = {
    initData: {},
};


module.exports = (User);
