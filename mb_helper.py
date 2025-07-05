#!/usr/bin/env python3
"""
MusicBrainz Helper Script for CD Ripping Workflow
Handles searching, matching, and potential submission to MusicBrainz
"""

import argparse
import json
import sys
import yaml
from typing import Dict, List, Optional, Tuple
import musicbrainzngs
from datetime import datetime
import requests

# Configure MusicBrainz client
musicbrainzngs.set_useragent("CD-Ripper-Helper", "1.0", "contact@example.com")

class MusicBrainzHelper:
    def __init__(self, email: str = "contact@example.com"):
        musicbrainzngs.set_useragent("CD-Ripper-Helper", "1.0", email)
        
    def search_releases(self, metadata: Dict) -> List[Dict]:
        """Search for existing releases in MusicBrainz"""
        album = metadata['album']
        artist = album['artist']
        title = album['title']
        barcode = album.get('barcode', '')
        
        results = []
        
        try:
            # Search by barcode first if available
            if barcode:
                print(f"🔍 Searching by barcode: {barcode}")
                barcode_results = musicbrainzngs.search_releases(barcode=barcode, limit=5)
                if barcode_results['release-list']:
                    results.extend(barcode_results['release-list'])
                    print(f"✅ Found {len(barcode_results['release-list'])} releases by barcode")
            
            # Search by artist and album
            print(f"🔍 Searching by artist/album: {artist} - {title}")
            search_results = musicbrainzngs.search_releases(
                artist=artist, 
                release=title, 
                limit=10
            )
            
            if search_results['release-list']:
                # Filter out duplicates from barcode search
                existing_ids = {r['id'] for r in results}
                new_results = [r for r in search_results['release-list'] 
                             if r['id'] not in existing_ids]
                results.extend(new_results)
                print(f"✅ Found {len(new_results)} additional releases by search")
            
            return results
            
        except Exception as e:
            print(f"❌ Error searching MusicBrainz: {e}")
            return []
    
    def display_search_results(self, results: List[Dict]) -> Optional[str]:
        """Display search results and let user choose"""
        if not results:
            print("❌ No matches found in MusicBrainz")
            print("📝 This appears to be a new release that could be added")
            return None
        
        print(f"\n🎵 Found {len(results)} potential matches:")
        print("-" * 80)
        
        for i, release in enumerate(results[:10], 1):
            artist_name = self._get_artist_name(release)
            print(f"{i:2d}. {release['title']} by {artist_name}")
            print(f"    ID: {release['id']}")
            
            if 'date' in release:
                print(f"    Date: {release['date']}")
            
            if 'label-info-list' in release:
                labels = self._get_labels(release)
                if labels:
                    print(f"    Label(s): {', '.join(labels)}")
            
            if 'barcode' in release:
                print(f"    Barcode: {release['barcode']}")
            
            print()
        
        # Ask user to choose
        while True:
            choice = input("Enter the number of matching release (1-10), 'n' for none, or 'd' for details: ").lower()
            
            if choice == 'n':
                return None
            elif choice == 'd':
                self._show_detailed_results(results)
                continue
            else:
                try:
                    idx = int(choice) - 1
                    if 0 <= idx < min(len(results), 10):
                        return results[idx]['id']
                    else:
                        print("❌ Invalid choice. Please try again.")
                except ValueError:
                    print("❌ Invalid input. Please try again.")
    
    def get_release_details(self, release_id: str) -> Optional[Dict]:
        """Get detailed information about a release"""
        try:
            result = musicbrainzngs.get_release_by_id(
                release_id,
                includes=['recordings', 'artist-credits', 'labels', 'discids']
            )
            return result['release']
        except Exception as e:
            print(f"❌ Error fetching release details: {e}")
            return None
    
    def compare_with_metadata(self, release_id: str, metadata: Dict) -> Dict:
        """Compare MusicBrainz release with local metadata"""
        release = self.get_release_details(release_id)
        if not release:
            return {}
        
        comparison = {
            'release_id': release_id,
            'mb_data': release,
            'differences': [],
            'track_differences': []
        }
        
        # Compare basic album info
        album = metadata['album']
        
        if release['title'] != album['title']:
            comparison['differences'].append({
                'field': 'title',
                'local': album['title'],
                'mb': release['title']
            })
        
        # Compare tracks
        if 'medium-list' in release:
            mb_tracks = []
            for medium in release['medium-list']:
                if 'track-list' in medium:
                    mb_tracks.extend(medium['track-list'])
            
            local_tracks = metadata['tracks']
            
            if len(mb_tracks) != len(local_tracks):
                comparison['track_differences'].append({
                    'issue': 'track_count',
                    'local': len(local_tracks),
                    'mb': len(mb_tracks)
                })
            
            # Compare individual tracks
            for i, (local_track, mb_track) in enumerate(zip(local_tracks, mb_tracks)):
                if local_track['title'] != mb_track['recording']['title']:
                    comparison['track_differences'].append({
                        'track': i + 1,
                        'field': 'title',
                        'local': local_track['title'],
                        'mb': mb_track['recording']['title']
                    })
        
        return comparison
    
    def suggest_submission(self, metadata: Dict) -> Dict:
        """Generate a submission suggestion for MusicBrainz"""
        album = metadata['album']
        tracks = metadata['tracks']
        
        suggestion = {
            'type': 'new_release',
            'album': {
                'title': album['title'],
                'artist': album['artist'],
                'date': album.get('date', ''),
                'label': album.get('label', ''),
                'barcode': album.get('barcode', ''),
                'country': album.get('country', ''),
                'status': 'Official',  # Assuming official release
                'packaging': 'Jewel Case',  # Default assumption
            },
            'tracks': [
                {
                    'position': track['number'],
                    'title': track['title'],
                    'artist': track.get('artist', album['artist']),
                    'length': track.get('length', '')
                }
                for track in tracks
            ],
            'submission_notes': [
                "This release was not found in MusicBrainz during automated search",
                "Metadata sourced from physical CD",
                f"Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
            ]
        }
        
        return suggestion
    
    def _get_artist_name(self, release: Dict) -> str:
        """Extract artist name from release data"""
        if 'artist-credit' in release and release['artist-credit']:
            return release['artist-credit'][0].get('name', 'Unknown')
        return 'Unknown'
    
    def _get_labels(self, release: Dict) -> List[str]:
        """Extract label names from release data"""
        if 'label-info-list' not in release:
            return []
        
        labels = []
        for label_info in release['label-info-list']:
            if 'label' in label_info and 'name' in label_info['label']:
                labels.append(label_info['label']['name'])
        return labels
    
    def _show_detailed_results(self, results: List[Dict]):
        """Show detailed information for search results"""
        for i, release in enumerate(results[:5], 1):
            print(f"\n=== Release {i}: {release['title']} ===")
            details = self.get_release_details(release['id'])
            if details:
                print(f"Artist: {self._get_artist_name(details)}")
                print(f"Date: {details.get('date', 'Unknown')}")
                print(f"Country: {details.get('country', 'Unknown')}")
                print(f"Status: {details.get('status', 'Unknown')}")
                
                if 'medium-list' in details:
                    total_tracks = sum(len(m.get('track-list', [])) for m in details['medium-list'])
                    print(f"Tracks: {total_tracks}")
                
                labels = self._get_labels(details)
                if labels:
                    print(f"Labels: {', '.join(labels)}")
            print()

def main():
    parser = argparse.ArgumentParser(description='MusicBrainz Helper for CD Ripping')
    parser.add_argument('metadata_file', help='YAML metadata file')
    parser.add_argument('--email', default='contact@example.com', 
                       help='Email for MusicBrainz API')
    parser.add_argument('--search-only', action='store_true',
                       help='Only search, don\'t prompt for choices')
    parser.add_argument('--output', help='Output file for results')
    
    args = parser.parse_args()
    
    # Load metadata
    try:
        with open(args.metadata_file, 'r') as f:
            metadata = yaml.safe_load(f)
    except Exception as e:
        print(f"❌ Error loading metadata file: {e}")
        sys.exit(1)
    
    # Initialize helper
    mb_helper = MusicBrainzHelper(args.email)
    
    # Search for releases
    results = mb_helper.search_releases(metadata)
    
    if args.search_only:
        # Just display results and exit
        if results:
            print(f"Found {len(results)} potential matches")
            for release in results[:5]:
                print(f"- {release['title']} by {mb_helper._get_artist_name(release)} ({release['id']})")
        else:
            print("No matches found")
        sys.exit(0)
    
    # Interactive mode
    release_id = mb_helper.display_search_results(results)
    
    if release_id:
        print(f"\n🎯 Selected release: {release_id}")
        comparison = mb_helper.compare_with_metadata(release_id, metadata)
        
        if comparison['differences'] or comparison['track_differences']:
            print("\n⚠️  Found differences between local metadata and MusicBrainz:")
            for diff in comparison['differences']:
                print(f"  {diff['field']}: '{diff['local']}' vs '{diff['mb']}'")
            for diff in comparison['track_differences']:
                if diff.get('track'):
                    print(f"  Track {diff['track']} {diff['field']}: '{diff['local']}' vs '{diff['mb']}'")
                else:
                    print(f"  {diff['issue']}: {diff['local']} vs {diff['mb']}")
        else:
            print("✅ Local metadata matches MusicBrainz release!")
    else:
        print("\n📝 No matching release found. Generating submission suggestion...")
        suggestion = mb_helper.suggest_submission(metadata)
        
        print("\n📋 Submission Suggestion:")
        print(f"Artist: {suggestion['album']['artist']}")
        print(f"Album: {suggestion['album']['title']}")
        print(f"Tracks: {len(suggestion['tracks'])}")
        print(f"Date: {suggestion['album']['date']}")
        print(f"Label: {suggestion['album']['label']}")
        
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(suggestion, f, indent=2)
            print(f"\n💾 Suggestion saved to: {args.output}")
        
        print("\n🌐 To submit this release to MusicBrainz:")
        print("1. Visit https://musicbrainz.org/")
        print("2. Create an account if you don't have one")
        print("3. Use 'Add Release' and fill in the suggested information")
        print("4. Include the generated submission notes")

if __name__ == '__main__':
    main()