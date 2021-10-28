// will check rights for action

const checkRights = (userRoles, docRights, action) => {
    let is_accepted = false;
    if (docRights && docRights[action]) {
        docRights[action].forEach(role => {
            // raamatupidajad
            is_accepted = userRoles && userRoles.is_raama && role == 'raama' ? true : is_accepted;

            if (!is_accepted) {
                is_accepted = userRoles && userRoles.is_juht && role == 'juht' ? true : is_accepted;
            }

            // adminid
            if (!is_accepted) {
                is_accepted = userRoles && userRoles.is_admin && role == 'admin' ? true : is_accepted;
            }

        });
    } else {
        // если нет ограничений
        is_accepted = true;
    }
    return is_accepted;
};
module.exports = checkRights;