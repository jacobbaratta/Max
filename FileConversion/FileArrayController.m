/*
 *  $Id$
 *
 *  Copyright (C) 2005, 2006 Stephen F. Booth <me@sbooth.org>
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

#import "FileArrayController.h"
#import "FileConversionController.h"

@interface FileArrayController (Private)
- (void)			moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet *)indexSet toIndex:(unsigned)insertIndex;
- (NSIndexSet *)	indexSetForRows:(NSArray *)rows;
- (int)				rowsAboveRow:(int)row inIndexSet:(NSIndexSet *)indexSet;
@end

@implementation FileArrayController

- (void) awakeFromNib
{
	[_tableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

- (BOOL) containsFile:(NSString *)filename
{
	return (nil == [self findFile:filename] ? NO :  YES);
}

- (NSDictionary *) findFile:(NSString *)filename
{
	// TODO: Should I use filteredArrayUsingPredicate: here?
	
	NSEnumerator			*enumerator;
	NSDictionary			*current;
	
	enumerator = [[self arrangedObjects] objectEnumerator];		
	while((current = [enumerator nextObject])) {
		if([[current valueForKey:@"filename"] isEqualToString:filename]) {
			return current;
		}
	}	
	
	return nil;
}

- (void) selectFile:(NSString *)filename
{
	NSDictionary *file = [self findFile:filename];
	if(nil != file) {
		[self setSelectionIndex:[[self arrangedObjects] indexOfObject:file]];
	}
}

- (BOOL) tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	NSArray				*rows				= [self arrangedObjects];
	NSMutableArray		*filenames			= [NSMutableArray arrayWithCapacity:[rowIndexes count]];
	unsigned			index				= [rowIndexes firstIndex];
		
	while(NSNotFound != index) {
		[filenames addObject:[[rows objectAtIndex:index] valueForKey:@"filename"]];
		index = [rowIndexes indexGreaterThanIndex:index];
	}
	
	[pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
	[pboard setPropertyList:filenames forType:NSFilenamesPboardType];

	return YES;
}

- (NSDragOperation) tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
	NSDragOperation		dragOperation		= NSDragOperationNone;

	// Move rows if this is an internal drag
	if(tv == [info draggingSource]) {
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
		dragOperation = NSDragOperationMove;
	}	
	else if([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType]) {
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
		dragOperation = NSDragOperationCopy;
	}

	return dragOperation;
}

- (BOOL) tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
	BOOL				success			= YES;

    if(0 > row) {
		row = 0;
	}
	
    if(_tableView == [info draggingSource]) {
		NSArray			*filenames		= [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSIndexSet		*indexSet		= [self indexSetForRows:filenames];
		int				rowsAbove;
		NSRange			range;

		[self moveObjectsInArrangedObjectsFromIndexes:indexSet toIndex:row];
		
		rowsAbove	= [self rowsAboveRow:row inIndexSet:indexSet];
		range		= NSMakeRange(row - rowsAbove, [indexSet count]);
		indexSet	= [NSIndexSet indexSetWithIndexesInRange:range];
		
		[self setSelectionIndexes:indexSet];
	}
	else if([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType]) {
		NSEnumerator		*enumerator;
		NSString			*current;
		NSMutableArray		*newFiles	= [NSMutableArray array];
		NSDictionary		*file;
		
		enumerator = [[[info draggingPasteboard] propertyListForType:NSFilenamesPboardType] objectEnumerator];
		while((current = [enumerator nextObject])) {
			
			success &= [[FileConversionController sharedController] addFile:current atIndex:row++];
			
			if(success) {
				file = [self findFile:current];
				if(nil != file) {
					[newFiles addObject:file];
				}
			}
		}
		
		if(success) {
			[self setSelectedObjects:newFiles];
		}		
	}
	
	return success;
}

@end

@implementation FileArrayController (Private)

- (void) moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)indexSet toIndex:(unsigned)insertIndex
{
	NSArray			*objects					= [self arrangedObjects];
	unsigned		index						= [indexSet lastIndex];
	unsigned		aboveInsertIndexCount		= 0;
	unsigned		removeIndex;
	id				object;

	while(NSNotFound != index) {
		if(index >= insertIndex) {
			removeIndex = index + aboveInsertIndexCount;
			++aboveInsertIndexCount;
	}
	else {
		removeIndex = index;
		--insertIndex;
	}
	object = [[objects objectAtIndex:removeIndex] retain];
	[self removeObjectAtArrangedObjectIndex:removeIndex];
	[self insertObject:[object autorelease] atArrangedObjectIndex:insertIndex];

	index = [indexSet indexLessThanIndex:index];
	}
}

- (NSIndexSet *) indexSetForRows:(NSArray *)rows
{
	NSArray					*arrangedObjects		= [self arrangedObjects];
	NSEnumerator			*enumerator				= nil;
	NSMutableIndexSet		*indexSet				= [NSMutableIndexSet indexSet];
	NSEnumerator			*rowEnumerator			= [rows objectEnumerator];
	id						object;
	NSString				*filename;

	while((filename = [rowEnumerator nextObject])) {
		enumerator = [arrangedObjects objectEnumerator];
		while((object = [enumerator nextObject])) {
			if([[object valueForKey:@"filename"] isEqualToString:filename]) {
				[indexSet addIndex:[arrangedObjects indexOfObject:object]];
			}
		}
	}

	return indexSet;
}

- (int) rowsAboveRow:(int)row inIndexSet:(NSIndexSet *)indexSet
{
	int				i				= 0;
	unsigned		currentIndex	= [indexSet firstIndex];

	while(NSNotFound != currentIndex) {
		if(currentIndex < (unsigned)row) {
			++i;
		}

		currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
	}

	return i;
}

@end
