'use strict';

const PropTypes = require('prop-types');
const {withRouter} = require('react-router-dom');
const fetchData = require('./../../../libs/fetchData');

const React = require('react'),
    ToolbarContainer = require('./../toolbar-container/toolbar-container.jsx'),
    BtnStart = require('./../button-register/button-register-start/button-register-start.jsx'),
    BtnLogin = require('./../button-register/button-login/button-login.jsx'),
    BtnEdit = require('./../button-register/button-register-edit/button-register-edit.jsx'),
    BtnInfo = require('./../button-register/button-info/index.jsx'),
    StartMenu = require('./../start-menu/start-menu.jsx'),
    SelectRekv = require('./../select-rekv/index.jsx'),
    Select = require('./../select/select.jsx'),
    BtnAccount = require('./../button-register/button-account/button-account.jsx');

const style = require('./menu-toolbar.styles');
const DocContext = require('./../../doc-context.js');
const DocRights = require('./../../../config/doc_rights');
const checkRights = require('./../../../libs/checkRights');


class MenuToolBar extends React.Component {
    constructor(props) {
        super(props);

        this.state = {
            logedIn: true,
            startMenuValue: 'parentid',
            showStartMenu: false,
            isOpenRekvPage: false,
            rekvId: props.rekvId ? props.rekvId : 1,
            keel: DocContext.keel
        };


        this.btnStartClick = this.btnStartClick.bind(this);
        this.btnLoginClick = this.btnLoginClick.bind(this);
        this.renderStartMenu = this.renderStartMenu.bind(this);
        this.startMenuClickHandler = this.startMenuClickHandler.bind(this);
        this.handleChange = this.handleChange.bind(this);
        this.handleChangeSelect = this.handleChangeSelect.bind(this);
        this.btnAccountClick = this.btnAccountClick.bind(this);
        this.btnEditRekvClick = this.btnEditRekvClick.bind(this);

    }

    render() {
        // права на редактирование карточки контрагента
        let docRightsRekv = DocRights['REKV'] ? DocRights['REKV'] : [];
        let userRoles = DocContext.userData ? DocContext.userData.roles : [];

        let isEditMode = this.props.edited,
            toolbarParams = {
                btnStart: {
                    show: this.props.params['btnStart'].show || false,
                    disabled: isEditMode
                },
                btnLogin: {
                    show: true,
                    disabled: false
                },
                btnAccount: {
                    show: this.state.logedIn || false,
                    disabled: false
                },
                btnInfo: {
                    show: true,
                    disabled: false
                }
            };

        let userAccessList = [];

        if (('userAccessList' in DocContext.userData)) {
            userAccessList = DocContext.userData.userAccessList.map((row) => {
                let rowObject = JSON.parse(row);
                return {id: rowObject.id, kood: '', name: rowObject.nimetus};
            });

            // сортировка
            userAccessList = userAccessList.sort((a, b) => {
                return a.name.localeCompare(b.name, 'en', {sensitivity: 'base'})
            });

        }

        let rekvId = this.state.rekvId,
            asutus = userAccessList.find(row => {
                return row.id == rekvId
            }).name;

        return (
            <div style={style['container']}>
                <p style={style['pageName']}> {DocContext.pageName ? DocContext.pageName : ''} </p>
                <ToolbarContainer
                    ref='menuToolbarContainer'
                    position="left">
                    <BtnStart ref='btnStart'
                              onClick={this.btnStartClick}
                              show={toolbarParams['btnStart'].show}
                              disabled={toolbarParams['btnStart'].disabled}
                    />

                    <SelectRekv name='rekvId'
                                libs="rekv"
                                style={style['selectStyle']}
                                data={userAccessList}
                                readOnly={false}
                                value={rekvId}
                                defaultValue={asutus}
                                collId='id'
                                ref='rekvId'
                                onChange={this.handleChange}/>
                    {checkRights(userRoles, docRightsRekv, 'edit') ?

                        <BtnEdit
                            ref='btnEditRekv'
                            value='Muuda'
                            onClick={this.btnEditRekvClick}
                        /> : null}
                    <BtnAccount ref='btnAccount'
                                value={DocContext.userData ? DocContext.userData.userName : ''}
                                onClick={this.btnAccountClick}
                                show={toolbarParams['btnAccount'].show}
                                disabled={toolbarParams['btnAccount'].disabled}/>
                    <BtnLogin ref='btnLogin'
                              value={this.state.logedIn ? 'Välju' : 'Sisse'}
                              onClick={this.btnLoginClick}
                              show={toolbarParams['btnLogin'].show}
                              disabled={toolbarParams['btnLogin'].disabled}/>
                    <select ref="select"
                            style={style['selectKeel']}
                            value={this.state.keel || 'Est'}
                            id={'keel'}
                            onChange={this.handleChangeSelect}>
                        <option value={'Est'} key={'est'}
                                ref={'Est'}> {'EST'} </option>
                        <option value={'RU'} key={'RU'}
                                ref={'RU'}> {'RU'} </option>
                        <option value={'ING'} key={'ING'}
                                ref={'ING'}> {'ING'} </option>
                    </select>
                    <BtnInfo ref='btnInfo'
                             value={'Juhend'}
                             show={toolbarParams['btnInfo'].show}/>
                </ToolbarContainer>
                {this.renderStartMenu()}

            </div>
        );
    }

    handleChangeSelect(e) {
        let fieldValue = e.target.value;

        DocContext.keel = fieldValue;
        this.setState({keel: fieldValue});
        const current = window.location.pathname;
        this.props.history.replace(`/reload`);
        setTimeout(() => {
            this.props.history.replace(current);
        });

    }

    renderStartMenu() {
        let component = null;
        let data = [];
        /*
                data = DocContext.menu;
        */
        if (this.state.showStartMenu) {
            component = <StartMenu ref='startMenu'
                                   value={this.state.startMenuValue}
                                   data={data}
                                   clickHandler={this.startMenuClickHandler}/>
        }
        return component
    }

    btnStartClick() {
        // обработчик для кнопки Start

        this.setState({showStartMenu: !this.state.showStartMenu});

    }

    /**
     * получит от стартого меню данные, спрячет меню
     */
    startMenuClickHandler(value) {
        this.setState({showStartMenu: false});

        let docType = DocContext['menu'].find(row => row.kood === value);
        if (docType) {
            DocContext.pageName = docType.name;
        }

        if (this.props.history) {
            return this.props.history.push({
                pathname: `/${DocContext.module}/${value}`,
                state: {module: DocContext.module}

            });
        } else {
            document.location.href = `/${DocContext.module}/${value}`
        }
    }

    btnLoginClick() {
        const URL = '/logout';
        this.setState({logedIn: false});

        try {
            let userId = DocContext.userData.userId;
            const params = {
                userId: userId, module: DocContext.module,
                uuid: this.state.logedIn ? DocContext.userData.uuid : null
            };

            fetchData.fetchDataPost(URL, params).then(() => {
                    DocContext.userData = null;
                }
            );
        } catch (e) {
            console.error(e);
        }
        document.location.href = '/login';
    }


    btnAccountClick() {
        return this.props.history.push({
            pathname: `/${DocContext.module}/userid/${DocContext.userData.userId}`,
            state: {module: DocContext.module}
        });


    }

    btnEditRekvClick() {
        return this.props.history.push({
            pathname: `/${DocContext.module}/rekv/${DocContext.userData.asutusId}`,
            state: {module: DocContext.module}
        });

    }

    handleChange(inputName, inputValue) {

        const URL = '/newApi/changeAsutus';
        let rekvId = inputValue; // choose asutusId

        if (!this.state.logedIn) {
            return;
        }

        // отправить пост запрос
        try {
            let localUrl = `${URL}/${rekvId}`;
            let userId = this.state.logedIn ? DocContext.userData.userId : null;
            let uuid = this.state.logedIn ? DocContext.userData.uuid : null;

            const params = {
                userId: userId,
                module: DocContext.module,
                docTypeId: DocContext.docTypeId,
                uuid: uuid
            };

            this.setState({rekvId: rekvId});

            fetchData.fetchDataPost(localUrl, params).then(response => {
                DocContext.userData = Object.assign(DocContext.userData, response.config.data);

                // redirect to main
                this.props.history.push({
                    pathname: `/${DocContext.module}/`,
                });
                document.location.reload();

            });

        } catch (e) {
            console.error(e);
        }
        // получить и сохрать данные пользователя
        // обновить регистр документов - перейти на главную страницу
    }


}

/*
MenuToolBar
    .propTypes = {
    edited: PropTypes.bool,
    params: PropTypes.object.isRequired,
    logedIn: PropTypes.bool
};


MenuToolBar
    .defaultProps = {
    edited: false,
    logedIn: false,
    params: {
        btnStart: {
            show: true
        }
    }
};
*/

module.exports = withRouter(MenuToolBar);