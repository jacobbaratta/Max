/*
 *  $Id: CompactDisc.h 122 2005-11-18 21:57:28Z me $
 *
 *  Copyright (C) 2005 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "CompactDisc.h"

#import "MallocException.h"
#import "ParanoiaException.h"
#import "FreeDBException.h"

@implementation CompactDisc

- (id) init
{
	if((self = [super init])) {
		_bsdName		= nil;
		_drive			= NULL;
		_freeDBDisc		= NULL;
		
		return self;
	}
	else {
		return nil;
	}
}

- (void) setBSDName:(NSString *)bsdName
{
	unsigned			i;
	unsigned long		discLength	= 150;

	// Cleanup
	if(nil != _bsdName) {
		[_bsdName release];
	}
	
	if(NULL != _drive) {
		cdda_close(_drive);
	}

	if(NULL != _freeDBDisc) {
		cddb_disc_destroy(_freeDBDisc);
	}
	
	
	_bsdName	= [bsdName retain];

	// cdparanoia setup
	_drive		= cdda_identify([_bsdName UTF8String], 0, NULL);
	if(NULL == _drive) {
		@throw [ParanoiaException exceptionWithReason:@"cdda_identify failed" userInfo:nil];
	}
	
	if(0 != cdda_open(_drive)) {
		@throw [ParanoiaException exceptionWithReason:@"cdda_open failed" userInfo:nil];
	}
	
	// Setup libcddb data structures
	_freeDBDisc	= cddb_disc_new();
	if(NULL == _freeDBDisc) {
		@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
	}
	
	for(i = 1; i <= [self trackCount]; ++i) {
		cddb_track_t	*cddb_track	= cddb_track_new();
		if(NULL == cddb_track) {
			@throw [MallocException exceptionWithReason:@"Unable to allocate memory" userInfo:nil];
		}
		cddb_track_set_frame_offset(cddb_track, [self firstSectorForTrack:i] + 150);
		cddb_disc_add_track(_freeDBDisc, cddb_track);
		discLength += [self lastSectorForTrack:i] - [self firstSectorForTrack:i] + 1;
	}
	cddb_disc_set_length(_freeDBDisc, (unsigned) (60 * (discLength / (60 * 75))) + (unsigned)((discLength / 75) % 60));
	
	if(0 == cddb_disc_calc_discid(_freeDBDisc)) {
		@throw [FreeDBException exceptionWithReason:@"Unable to calculate disc id" userInfo:nil];
	}
}

- (void) dealloc
{
	if(nil != _bsdName) {
		[_bsdName release];
	}
	
	if(NULL != _drive) {
		cdda_close(_drive);
	}
	
	if(NULL != _freeDBDisc) {
		cddb_disc_destroy(_freeDBDisc);
	}
	
	[super dealloc];
}

- (unsigned) trackCount
{
	return cdda_tracks(_drive);
}

- (unsigned long) firstSector
{
	return cdda_disc_firstsector(_drive);
}

- (unsigned long) lastSector
{
	return cdda_disc_lastsector(_drive);
}

- (unsigned) trackContainingSector:(unsigned long) sector
{
	return cdda_sector_gettrack(_drive, sector);
}

- (unsigned long) firstSectorForTrack:(ssize_t) track
{
	return cdda_track_firstsector(_drive, track);
}

- (unsigned long) lastSectorForTrack:(ssize_t) track
{
	return cdda_track_lastsector(_drive, track);
}

- (unsigned) channelsForTrack:(ssize_t) track;
{
	return cdda_track_channels(_drive, track);
}

- (BOOL) trackContainsAudio:(ssize_t) track
{
	return cdda_track_audiop(_drive, track) ? YES : NO;
}

- (BOOL) trackHasPreEmphasis:(ssize_t) track
{
	return cdda_track_preemp(_drive, track) ? YES : NO;
}

- (BOOL) trackAllowsDigitalCopy:(ssize_t) track
{
	return cdda_track_copyp(_drive, track) ? YES : NO;
}

- (int) discID
{
	return cddb_get_disc_id(_freeDBDisc);
}

@end
