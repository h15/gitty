create table `user`
(
    `id`        int(11) unsigned not null auto_increment primary key,
    `mail`      varchar(255) character set utf8 collate utf8_general_ci not null,
    `name`      varchar(255) character set utf8 collate utf8_general_ci not null,
    `createAt`  int(11) not null,
    `modifyAt`  int(11) not null,
    `accessAt`  int(11) not null,
    `banId`     int(11) not null default 0,
    `banTime`   int(11) not null default 0,
    
    unique (`mail`),
    unique (`name`),
    
    FOREIGN KEY (`banId`)  REFERENCES `ban`(`id`)
);

create table `mailConfirm`
(
    `expair`    int(11) unsigned not null default 0,
    `mail`      varchar(255) character set utf8 collate utf8_general_ci not null primary key,
    `secret`    varchar(32) character set ascii collate ascii_general_ci not null,
    `attempts`  int(1) unsigned not null default 0
);

create table `ban`
(
    `id`        int(11) unsigned not null auto_increment primary key,
    `desc`      varchar(255) character set utf8 collate utf8_general_ci not null,
    `userId`    int(11) unsigned not null,
    `time`      int(11) unsigned not null default 0,
    `expair`    int(11) unsigned not null,
    
    FOREIGN KEY (`userId`)  REFERENCES `user`(`id`)
);

create table `group`
(
    `id`        int(11) unsigned not null auto_increment primary key,
    `name`      varchar(64) character set utf8 collate utf8_general_ci not null,
    `desc`      varchar(1024) character set utf8 collate utf8_general_ci not null,
    `prioritet` int(11) unsigned not null default 0
);

create table `userToGroup`
(
    `userId`    int(11) unsigned not null,
    `groupId`   int(11) unsigned not null,
    
    FOREIGN KEY (`userId`)  REFERENCES `user`(`id`),
    FOREIGN KEY (`groupId`) REFERENCES `group`(`id`)
);

create table `access`
(
    `groupId`   int(11) unsigned not null,
    `dataTypeId`int(11) unsigned not null,
    `RWCD`      int(11) unsigned not null default 0,
    
    FOREIGN KEY (`groupId`)    REFERENCES `group`(`id`),
    FOREIGN KEY (`dataTypeId`) REFERENCES `dataType`(`id`)
);

create table `dataType`
(
    `id`        int(11) unsigned not null auto_increment primary key,
    `name`      varchar(64) character set utf8 collate utf8_general_ci not null,
    `desc`      varchar(1024) character set utf8 collate utf8_general_ci not null,
    `prioritet` int(11) unsigned not null default 0
);

create table `threadToDataType`
(
    `threadId`  int(11) unsigned not null,
    `dataTypeId`int(11) unsigned not null,
    
    FOREIGN KEY (`threadId`)   REFERENCES `thread`(`id`),
    FOREIGN KEY (`dataTypeId`) REFERENCES `dataType`(`id`)
);

create table `thread`
(
    `id`        int(11) unsigned not null auto_increment primary key,
    `userId`    int(11) unsigned not null default 0,
    `createAt`  int(11) unsigned not null,
    `modifyAt`  int(11) unsigned not null,
    `parentId`  int(11) unsigned not null,
    `topicId`   int(11) unsigned not null,
    `textId`    int(11) unsigned not null,
    
    FOREIGN KEY (`userId`)   REFERENCES `user`(`id`),
    FOREIGN KEY (`parentId`) REFERENCES `thread`(`id`),
    FOREIGN KEY (`topicId`)  REFERENCES `topic`(`id`),
    FOREIGN KEY (`textId`)   REFERENCES `text`(`id`)
);

create table `text`
(
    `id`        int(11) unsigned not null auto_increment primary key,
    `threadId`  int(11) unsigned not null,
    `text`      varchar(60000) character set utf8 collate utf8_general_ci not null,
    
    FOREIGN KEY (`threadId`)  REFERENCES `thread`(`id`)
);

create table `topic`
(
    `threadId`  int(11) unsigned not null,
    `title`     varchar(64) character set utf8 collate utf8_general_ci not null,
    `url`       varchar(64) character set ascii collate ascii_general_ci not null primary key,
    
    FOREIGN KEY (`threadId`)  REFERENCES `thread`(`id`)
);

create table `threadToTag`
(
    `threadId`  int(11) unsigned not null,
    `tagId`     int(11) unsigned not null,
    
    FOREIGN KEY (`threadId`) REFERENCES `thread`(`id`),
    FOREIGN KEY (`tagId`)    REFERENCES `tag`(`id`)
);

create table `tag`
(
    `id`        int(11) unsigned not null auto_increment primary key,
    `url`       varchar(64) character set ascii collate ascii_general_ci not null,
    `name`      varchar(64) character set utf8 collate utf8_general_ci not null,
    
    unique(`url`)
);
