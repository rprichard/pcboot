#ifndef EXT2FS_H
#define EXT2FS_H

#include <stdint.h>

/*
 * Constants relative to the data blocks
 */
#define EXT2_NDIR_BLOCKS        12
#define EXT2_IND_BLOCK          EXT2_NDIR_BLOCKS
#define EXT2_DIND_BLOCK         (EXT2_IND_BLOCK + 1)
#define EXT2_TIND_BLOCK         (EXT2_DIND_BLOCK + 1)
#define EXT2_N_BLOCKS           (EXT2_TIND_BLOCK + 1)

/*
 * Super block for an ext2fs file system.
 */
struct ext2fs {
    uint32_t  e2fs_icount;      /* Inode count */
    uint32_t  e2fs_bcount;      /* blocks count */
    uint32_t  e2fs_rbcount;     /* reserved blocks count */
    uint32_t  e2fs_fbcount;     /* free blocks count */
    uint32_t  e2fs_ficount;     /* free inodes count */
    uint32_t  e2fs_first_dblock;/* first data block */
    uint32_t  e2fs_log_bsize;   /* block size = 1024*(2^e2fs_log_bsize) */
    uint32_t  e2fs_log_fsize;   /* fragment size */
    uint32_t  e2fs_bpg;         /* blocks per group */
    uint32_t  e2fs_fpg;         /* frags per group */
    uint32_t  e2fs_ipg;         /* inodes per group */
    uint32_t  e2fs_mtime;       /* mount time */
    uint32_t  e2fs_wtime;       /* write time */
    uint16_t  e2fs_mnt_count;   /* mount count */
    uint16_t  e2fs_max_mnt_count;   /* max mount count */
    uint16_t  e2fs_magic;       /* magic number */
    uint16_t  e2fs_state;       /* file system state */
    uint16_t  e2fs_beh;         /* behavior on errors */
    uint16_t  e2fs_minrev;      /* minor revision level */
    uint32_t  e2fs_lastfsck;    /* time of last fsck */
    uint32_t  e2fs_fsckintv;    /* max time between fscks */
    uint32_t  e2fs_creator;     /* creator OS */
    uint32_t  e2fs_rev;         /* revision level */
    uint16_t  e2fs_ruid;        /* default uid for reserved blocks */
    uint16_t  e2fs_rgid;        /* default gid for reserved blocks */
    /* EXT2_DYNAMIC_REV superblocks */
    uint32_t  e2fs_first_ino;   /* first non-reserved inode */
    uint16_t  e2fs_inode_size;  /* size of inode structure */
    uint16_t  e2fs_block_group_nr;  /* block grp number of this sblk*/
    uint32_t  e2fs_features_compat; /*  compatible feature set */
    uint32_t  e2fs_features_incompat; /* incompatible feature set */
    uint32_t  e2fs_features_rocompat; /* RO-compatible feature set */
    uint8_t   e2fs_uuid[16];        /* 128-bit uuid for volume */
    char      e2fs_vname[16];       /* volume name */
    char      e2fs_fsmnt[64];       /* name mounted on */
    uint32_t  e2fs_algo;            /* For compression */
    uint8_t   e2fs_prealloc;        /* # of blocks for old prealloc */
    uint8_t   e2fs_dir_prealloc;    /* # of blocks for old prealloc dirs */
    uint16_t  e2fs_reserved_ngdb;   /* # of reserved gd blocks for resize */
    char      e3fs_journal_uuid[16]; /* uuid of journal superblock */
    uint32_t  e3fs_journal_inum;    /* inode number of journal file */
    uint32_t  e3fs_journal_dev;     /* device number of journal file */
    uint32_t  e3fs_last_orphan;     /* start of list of inodes to delete */
    uint32_t  e3fs_hash_seed[4];    /* HTREE hash seed */
    char      e3fs_def_hash_version; /* Default hash version to use */
    char      e3fs_reserved_char_pad;
    uint32_t  e3fs_default_mount_opts;
    uint32_t  e3fs_first_meta_bg;   /* First metablock block group */
    uint32_t  e3fs_mkfs_time;       /* when the fs was created */
    uint32_t  e3fs_jnl_blks[17];    /* backup of the journal inode */
    uint32_t  e4fs_bcount_hi;       /* block count */
    uint32_t  e4fs_rbcount_hi;      /* reserved blocks count */
    uint32_t  e4fs_fbcount_hi;      /* free blocks count */
    uint16_t  e4fs_min_extra_isize; /* all inodes have at least some bytes */
    uint16_t  e4fs_want_extra_isize; /* inodes must reserve some bytes */
    uint32_t  e4fs_flags;           /* miscellaneous flags */
    uint16_t  e4fs_raid_stride;     /* RAID stride */
    uint16_t  e4fs_mmpintv; /* number of seconds to wait in MMP checking */
    uint64_t  e4fs_mmpblk;   /* block for multi-mount protection */
    uint32_t  e4fs_raid_stripe_wid;/* blocks on all data disks (N * stride) */
    uint8_t   e4fs_log_gpf; /* FLEX_BG group size */
    uint8_t   e4fs_char_pad2;
    uint16_t  e4fs_pad;
    uint32_t  reserved2[162];   /* Padding to the end of the block */
};

/*
 * The second extended file system magic number
 */
#define E2FS_MAGIC      0xEF53

/*
 * Revision levels
 */
#define E2FS_REV0       0   /* The good old (original) format */
#define E2FS_REV1       1   /* V2 format w/ dynamic inode sizes */

#define E2FS_CURRENT_REV    E2FS_REV0
#define E2FS_MAX_SUPP_REV   E2FS_REV1

#define E2FS_REV0_INODE_SIZE 128

/*
 * compatible/incompatible features
 */
#define EXT2F_COMPAT_PREALLOC       0x0001
#define EXT2F_COMPAT_HASJOURNAL     0x0004
#define EXT2F_COMPAT_RESIZE         0x0010

#define EXT2F_ROCOMPAT_SPARSESUPER  0x0001
#define EXT2F_ROCOMPAT_LARGEFILE    0x0002
#define EXT2F_ROCOMPAT_BTREE_DIR    0x0004
#define EXT4F_ROCOMPAT_EXTRA_ISIZE  0x0040

#define EXT2F_INCOMPAT_COMP         0x0001
#define EXT2F_INCOMPAT_FTYPE        0x0002

/*
 * File clean flags
 */
#define E2FS_ISCLEAN        0x0001  /* Unmounted cleanly */
#define E2FS_ERRORS         0x0002  /* Errors detected */

/* ext2 file system block group descriptor */

struct ext2_gd {
    uint32_t ext2bgd_b_bitmap;  /* blocks bitmap block */
    uint32_t ext2bgd_i_bitmap;  /* inodes bitmap block */
    uint32_t ext2bgd_i_tables;  /* inodes table block  */
    uint16_t ext2bgd_nbfree;    /* number of free blocks */
    uint16_t ext2bgd_nifree;    /* number of free inodes */
    uint16_t ext2bgd_ndirs;     /* number of directories */
    uint16_t reserved;
    uint32_t reserved2[3];
};

#define EXT2_MIN_BLOCK_SIZE     1024
#define EXT2_MAX_BLOCK_SIZE     4096
#define EXT2_MIN_BLOCK_LOG_SIZE 10

/*
 * Special inode numbers
 * The root inode is the root of the file system.  Inode 0 can't be used for
 * normal purposes and bad blocks are normally linked to inode 1, thus
 * the root inode is 2.
 * Inode 3 to 10 are reserved in ext2fs.
 */
#define EXT2_BADBLKINO      ((ino_t)1)
#define EXT2_ROOTINO        ((ino_t)2)
#define EXT2_ACLIDXINO      ((ino_t)3)
#define EXT2_ACLDATAINO     ((ino_t)4)
#define EXT2_BOOTLOADERINO  ((ino_t)5)
#define EXT2_UNDELDIRINO    ((ino_t)6)
#define EXT2_RESIZEINO      ((ino_t)7)
#define EXT2_JOURNALINO     ((ino_t)8)
#define EXT2_FIRSTINO       ((ino_t)11)

/*
 * Structure of an inode on the disk
 */
struct ext2fs_dinode {
    uint16_t    e2di_mode;      /*   0: IFMT, permissions; see below. */
    uint16_t    e2di_uid;       /*   2: Owner UID */
    uint32_t    e2di_size;      /*   4: Size (in bytes) */
    uint32_t    e2di_atime;     /*   8: Access time */
    uint32_t    e2di_ctime;     /*  12: Change time */
    uint32_t    e2di_mtime;     /*  16: Modification time */
    uint32_t    e2di_dtime;     /*  20: Deletion time */
    uint16_t    e2di_gid;       /*  24: Owner GID */
    uint16_t    e2di_nlink;     /*  26: File link count */
    uint32_t    e2di_nblock;    /*  28: Blocks count */
    uint32_t    e2di_flags;     /*  32: Status flags (chflags) */
    uint32_t    e2di_version;   /*  36: Low 32 bits inode version */
    uint32_t    e2di_blocks[EXT2_N_BLOCKS]; /* 40: disk blocks */
    uint32_t    e2di_gen;       /* 100: generation number */
    uint32_t    e2di_facl;      /* 104: file ACL (not implemented) */
    uint32_t    e2di_dacl;      /* 108: dir ACL (not implemented) */
    uint32_t    e2di_faddr;     /* 112: fragment address */
    uint8_t     e2di_nfrag;     /* 116: fragment number */
    uint8_t     e2di_fsize;     /* 117: fragment size */
    uint16_t    e2di_linux_reserved2;   /* 118 */
    uint16_t    e2di_uid_high;          /* 120: Owner UID top 16 bits */
    uint16_t    e2di_gid_high;          /* 122: Owner GID top 16 bits */
    uint32_t    e2di_linux_reserved3;   /* 124 */
    uint16_t    e2di_extra_isize;
    uint16_t    e2di_pad1;
    uint32_t    e2di_ctime_extra;   /* Extra change time */
    uint32_t    e2di_mtime_extra;   /* Extra modification time */
    uint32_t    e2di_atime_extra;   /* Extra access time */
    uint32_t    e2di_crtime;        /* Creation (birth)time */
    uint32_t    e2di_crtime_extra;  /* Extra creation (birth)time */
    uint32_t    e2di_version_hi;    /* High 30 bits of inode version */
};

/*
 * Structure of a directory entry
 */
#define EXT2FS_MAXNAMLEN 255

struct  ext2fs_direct {
    uint32_t e2d_ino;           /* inode number of entry */
    uint16_t e2d_reclen;        /* length of this record */
    uint16_t e2d_namlen;        /* length of string in d_name */
    char e2d_name[EXT2FS_MAXNAMLEN];/* name with length<=EXT2FS_MAXNAMLEN */
};

/*
 * The new version of the directory entry.  Since EXT2 structures are
 * stored in intel byte order, and the name_len field could never be
 * bigger than 255 chars, it's safe to reclaim the extra byte for the
 * file_type field.
 */
struct  ext2fs_direct_2 {
    uint32_t e2d_ino;       /* inode number of entry */
    uint16_t e2d_reclen;    /* length of this record */
    uint8_t e2d_namlen;     /* length of string in d_name */
    uint8_t e2d_type;       /* file type */
    char e2d_name[EXT2FS_MAXNAMLEN];/* name with length<=EXT2FS_MAXNAMLEN */
};

/*
 * Ext2 directory file types.  Only the low 3 bits are used.  The
 * other bits are reserved for now.
 */
#define EXT2_FT_UNKNOWN     0
#define EXT2_FT_REG_FILE    1
#define EXT2_FT_DIR         2
#define EXT2_FT_CHRDEV      3
#define EXT2_FT_BLKDEV      4
#define EXT2_FT_FIFO        5
#define EXT2_FT_SOCK        6
#define EXT2_FT_SYMLINK     7

#define EXT2_FT_MAX         8

#endif /* EXT2FS_H */
